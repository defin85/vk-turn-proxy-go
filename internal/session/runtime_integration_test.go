package session

import (
	"context"
	"errors"
	"net"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
	"github.com/defin85/vk-turn-proxy-go/test/turnlab"
)

func TestRunRelayRoundTrip(t *testing.T) {
	harnessCtx, cancelHarness := context.WithCancel(context.Background())
	harness, err := turnlab.Start(harnessCtx, testLogger())
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancelHarness()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	sessionCtx, cancelSession := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	listenAddr := reserveUDPAddr(t)
	go func() {
		errCh <- Run(sessionCtx, config.ClientConfig{
			Provider:    "generic-turn",
			Link:        harness.GenericTurnLink(),
			ListenAddr:  listenAddr,
			PeerAddr:    harness.Descriptor.PeerAddress,
			Connections: 1,
			Mode:        config.TransportModeAuto,
			UseDTLS:     true,
		}, Dependencies{
			Registry:  provider.NewRegistry(genericturn.New()),
			Logger:    testLogger(),
			SessionID: NewID(),
		})
	}()

	clientConn, err := net.Dial("udp", listenAddr)
	if err != nil {
		cancelSession()
		t.Fatalf("dial local client addr: %v", err)
	}
	t.Cleanup(func() {
		_ = clientConn.Close()
	})

	payload := []byte("session-round-trip")
	mustEchoEventually(t, clientConn, payload)

	cancelSession()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Run() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("session did not stop after cancellation")
	}
}

func TestRunRoutesInjectedUpstreamReplyToMostRecentLocalSender(t *testing.T) {
	harnessCtx, cancelHarness := context.WithCancel(context.Background())
	harness, err := turnlab.Start(harnessCtx, testLogger())
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancelHarness()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	sessionCtx, cancelSession := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	listenAddr := reserveUDPAddr(t)
	go func() {
		errCh <- Run(sessionCtx, config.ClientConfig{
			Provider:    "generic-turn",
			Link:        harness.GenericTurnLink(),
			ListenAddr:  listenAddr,
			PeerAddr:    harness.Descriptor.PeerAddress,
			Connections: 1,
			Mode:        config.TransportModeUDP,
			UseDTLS:     true,
		}, Dependencies{
			Registry:  provider.NewRegistry(genericturn.New()),
			Logger:    testLogger(),
			SessionID: NewID(),
		})
	}()
	t.Cleanup(func() {
		cancelSession()
		select {
		case err := <-errCh:
			if err != nil {
				t.Errorf("Run() error = %v", err)
			}
		case <-time.After(5 * time.Second):
			t.Errorf("session did not stop after cancellation")
		}
	})

	connA, err := net.Dial("udp", listenAddr)
	if err != nil {
		t.Fatalf("dial client A: %v", err)
	}
	t.Cleanup(func() { _ = connA.Close() })

	connB, err := net.Dial("udp", listenAddr)
	if err != nil {
		t.Fatalf("dial client B: %v", err)
	}
	t.Cleanup(func() { _ = connB.Close() })

	mustEchoEventually(t, connA, []byte("sender-a"))
	mustEchoEventually(t, connB, []byte("sender-b"))
	drainConn(t, connA, 100*time.Millisecond)
	drainConn(t, connB, 100*time.Millisecond)

	waitCtx, cancelWait := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancelWait()
	if _, err := harness.WaitUpstreamPeer(waitCtx); err != nil {
		t.Fatalf("wait upstream peer: %v", err)
	}

	injected := []byte("upstream-injected")
	if err := harness.InjectUpstream(injected); err != nil {
		t.Fatalf("inject upstream packet: %v", err)
	}

	mustReadExact(t, connB, injected)
	mustNotRead(t, connA, 300*time.Millisecond)
}

func TestRunFailsBeforeListenerOnProviderError(t *testing.T) {
	cfg := validClientConfig()
	cfg.ListenAddr = reserveUDPAddr(t)

	adapter := &fakeAdapter{
		name: "fake",
		err:  errors.New("provider input invalid"),
	}

	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.ProviderResolve {
		t.Fatalf("unexpected stage: %v", err)
	}

	conn, listenErr := net.ListenPacket("udp", cfg.ListenAddr)
	if listenErr != nil {
		t.Fatalf("expected listener address to remain free, got %v", listenErr)
	}
	_ = conn.Close()
}

func TestRunFailsOnBadTURNCredentials(t *testing.T) {
	harnessCtx, cancelHarness := context.WithCancel(context.Background())
	harness, err := turnlab.Start(harnessCtx, testLogger())
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancelHarness()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	badLink := strings.Replace(harness.GenericTurnLink(), "turn-lab-pass", "wrong-pass", 1)
	recorder := &transportAddrRecorder{}
	listenAddr := reserveUDPAddr(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	err = Run(ctx, config.ClientConfig{
		Provider:    "generic-turn",
		Link:        badLink,
		ListenAddr:  listenAddr,
		PeerAddr:    harness.Descriptor.PeerAddress,
		Connections: 1,
		Mode:        config.TransportModeUDP,
		UseDTLS:     true,
	}, Dependencies{
		Registry:  provider.NewRegistry(genericturn.New()),
		Logger:    testLogger(),
		NewRunner: recorder.RunnerFactory(),
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.TURNAllocate {
		t.Fatalf("unexpected stage: %v", err)
	}
	mustRebindPacket(t, listenAddr)
	mustRebindPacket(t, recorder.Local())
	mustRebindPacket(t, recorder.TURNBase())
}

func TestRunFailsOnBadDTLSPeer(t *testing.T) {
	harnessCtx, cancelHarness := context.WithCancel(context.Background())
	harness, err := turnlab.Start(harnessCtx, testLogger())
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancelHarness()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	plainPeer, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen plain udp peer: %v", err)
	}
	t.Cleanup(func() {
		_ = plainPeer.Close()
	})
	recorder := &transportAddrRecorder{}
	listenAddr := reserveUDPAddr(t)

	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	err = Run(ctx, config.ClientConfig{
		Provider:    "generic-turn",
		Link:        harness.GenericTurnLink(),
		ListenAddr:  listenAddr,
		PeerAddr:    plainPeer.LocalAddr().String(),
		Connections: 1,
		Mode:        config.TransportModeUDP,
		UseDTLS:     true,
	}, Dependencies{
		Registry:  provider.NewRegistry(genericturn.New()),
		Logger:    testLogger(),
		NewRunner: recorder.RunnerFactory(),
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.DTLSHandshake {
		t.Fatalf("unexpected stage: %v", err)
	}
	mustRebindPacket(t, listenAddr)
	mustRebindPacket(t, recorder.Local())
	mustRebindPacket(t, recorder.TURNBase())
	mustRebindPacket(t, recorder.Relay())
}

type transportAddrRecorder struct {
	mu       sync.Mutex
	local    string
	turnBase string
	relay    string
}

func (r *transportAddrRecorder) RunnerFactory() RunnerFactory {
	return func(cfg transport.ClientConfig) transport.Runner {
		cfg.Hooks = transport.ClientHooks{
			OnLocalBind: func(addr net.Addr) {
				r.setLocal(addr)
			},
			OnTURNBaseBind: func(addr net.Addr) {
				r.setTURNBase(addr)
			},
			OnRelayAllocate: func(addr net.Addr) {
				r.setRelay(addr)
			},
		}

		return transport.NewClientRunner(cfg)
	}
}

func (r *transportAddrRecorder) setLocal(addr net.Addr) {
	if addr == nil {
		return
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.local = addr.String()
}

func (r *transportAddrRecorder) setTURNBase(addr net.Addr) {
	if addr == nil {
		return
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.turnBase = addr.String()
}

func (r *transportAddrRecorder) setRelay(addr net.Addr) {
	if addr == nil {
		return
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.relay = addr.String()
}

func (r *transportAddrRecorder) Local() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.local
}

func (r *transportAddrRecorder) TURNBase() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.turnBase
}

func (r *transportAddrRecorder) Relay() string {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.relay
}

func reserveUDPAddr(t *testing.T) string {
	t.Helper()

	conn, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("reserve udp addr: %v", err)
	}
	addr := conn.LocalAddr().String()
	if err := conn.Close(); err != nil {
		t.Fatalf("close reserved udp addr: %v", err)
	}

	return addr
}

func mustEchoEventually(t *testing.T, conn net.Conn, payload []byte) {
	t.Helper()

	buf := make([]byte, 1600)
	deadline := time.Now().Add(5 * time.Second)

	for time.Now().Before(deadline) {
		if err := conn.SetDeadline(time.Now().Add(200 * time.Millisecond)); err != nil {
			t.Fatalf("set deadline: %v", err)
		}
		if _, err := conn.Write(payload); err != nil {
			continue
		}

		n, err := conn.Read(buf)
		if err != nil {
			continue
		}
		if string(buf[:n]) != string(payload) {
			t.Fatalf("unexpected payload: got %q want %q", buf[:n], payload)
		}

		return
	}

	t.Fatalf("timed out waiting for echo %q", payload)
}

func mustReadExact(t *testing.T, conn net.Conn, payload []byte) {
	t.Helper()

	buf := make([]byte, 1600)
	if err := conn.SetDeadline(time.Now().Add(2 * time.Second)); err != nil {
		t.Fatalf("set deadline: %v", err)
	}
	n, err := conn.Read(buf)
	if err != nil {
		t.Fatalf("read payload: %v", err)
	}
	if got := string(buf[:n]); got != string(payload) {
		t.Fatalf("unexpected payload: got %q want %q", got, payload)
	}
}

func mustNotRead(t *testing.T, conn net.Conn, timeout time.Duration) {
	t.Helper()

	buf := make([]byte, 1600)
	if err := conn.SetDeadline(time.Now().Add(timeout)); err != nil {
		t.Fatalf("set deadline: %v", err)
	}
	if n, err := conn.Read(buf); err == nil {
		t.Fatalf("unexpected payload: %q", buf[:n])
	} else {
		var netErr net.Error
		if !errors.As(err, &netErr) || !netErr.Timeout() {
			t.Fatalf("expected timeout, got %v", err)
		}
	}
}

func drainConn(t *testing.T, conn net.Conn, timeout time.Duration) {
	t.Helper()

	buf := make([]byte, 1600)
	deadline := time.Now().Add(timeout)
	for {
		if err := conn.SetDeadline(time.Now().Add(20 * time.Millisecond)); err != nil {
			t.Fatalf("set deadline: %v", err)
		}
		if _, err := conn.Read(buf); err != nil {
			var netErr net.Error
			if errors.As(err, &netErr) && netErr.Timeout() {
				if time.Now().After(deadline) {
					return
				}
				continue
			}
			return
		}
		if time.Now().After(deadline) {
			return
		}
	}
}

func mustRebindPacket(t *testing.T, addr string) {
	t.Helper()

	if strings.TrimSpace(addr) == "" {
		t.Fatal("expected non-empty address for rebind check")
	}

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		conn, err := net.ListenPacket("udp", addr)
		if err == nil {
			if err := conn.Close(); err != nil {
				t.Fatalf("close rebound conn %s: %v", addr, err)
			}

			return
		}

		time.Sleep(20 * time.Millisecond)
	}

	t.Fatalf("rebind %s: address stayed busy past deadline", addr)
}
