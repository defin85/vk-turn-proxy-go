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
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
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

func TestRunSupervisedRelayRoundTrip(t *testing.T) {
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
			Connections: 2,
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

	for _, payload := range [][]byte{
		[]byte("session-supervision-round-trip-1"),
		[]byte("session-supervision-round-trip-2"),
		[]byte("session-supervision-round-trip-3"),
	} {
		mustEchoEventually(t, clientConn, payload)
	}

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

func TestRunKeepsRelayAliveThroughTURNRefresh(t *testing.T) {
	harnessCtx, cancelHarness := context.WithCancel(context.Background())
	harness, err := turnlab.StartWithOptions(harnessCtx, testLogger(), turnlab.Options{
		AllocationLifetime: 2 * time.Second,
	})
	if err != nil {
		t.Fatalf("start harness: %v", err)
	}
	t.Cleanup(func() {
		cancelHarness()
		if err := harness.Close(); err != nil {
			t.Errorf("close harness: %v", err)
		}
	})

	recorder := &transportAddrRecorder{}
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
			NewRunner: recorder.RunnerFactory(),
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

	mustEchoEventually(t, clientConn, []byte("before-turn-refresh"))

	waitCtx, waitCancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer waitCancel()
	if err := harness.WaitRefreshCount(waitCtx, 1); err != nil {
		cancelSession()
		t.Fatalf("wait refresh count: %v", err)
	}

	if got := recorder.TURNBaseCount(); got != 1 {
		cancelSession()
		t.Fatalf("turn base bind count = %d, want 1", got)
	}
	if got := recorder.RelayCount(); got != 1 {
		cancelSession()
		t.Fatalf("relay allocation count = %d, want 1", got)
	}

	mustEchoEventually(t, clientConn, []byte("after-turn-refresh"))

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

func TestRunRelayRoundTripUpdatesForwardingMetrics(t *testing.T) {
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

	metrics := observe.NewMetrics()
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
			Metrics:   metrics,
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

	mustEchoEventually(t, clientConn, []byte("metric-round-trip"))

	cancelSession()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Run() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("session did not stop after cancellation")
	}

	text := metrics.Prometheus()
	for _, expected := range []string{
		`vk_turn_proxy_runtime_forwarded_packets_total{direction="local_to_relay",provider="generic-turn",runtime="client"} 1`,
		`vk_turn_proxy_runtime_forwarded_packets_total{direction="relay_to_local",provider="generic-turn",runtime="client"} 1`,
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("metrics output missing %q:\n%s", expected, text)
		}
	}
}

func TestRunRestartsRealTransportWorkerAfterRuntimeFailure(t *testing.T) {
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

	restartProbe := newTransportRestartProbe()
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
			Registry:          provider.NewRegistry(genericturn.New()),
			Logger:            testLogger(),
			NewRunner:         restartProbe.RunnerFactory(),
			RestartBackoff:    10 * time.Millisecond,
			MaxWorkerRestarts: 1,
			SessionID:         NewID(),
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

	restartProbe.mustWaitReady(t, 0)
	if _, err := clientConn.Write([]byte("restart-trigger")); err != nil {
		cancelSession()
		t.Fatalf("write restart trigger: %v", err)
	}
	restartProbe.mustWaitReady(t, 1)
	drainConn(t, clientConn, 200*time.Millisecond)

	mustEchoEventually(t, clientConn, []byte("post-restart-round-trip"))

	if restartProbe.turnBaseCount() < 2 {
		cancelSession()
		t.Fatalf("turn base bind count = %d, want >= 2", restartProbe.turnBaseCount())
	}
	if restartProbe.relayCount() < 2 {
		cancelSession()
		t.Fatalf("relay allocation count = %d, want >= 2", restartProbe.relayCount())
	}

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
	mustRebindAddr(t, recorder.TURNBase())
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
	mustRebindAddr(t, recorder.TURNBase())
	mustRebindAddr(t, recorder.Relay())
}

type transportAddrRecorder struct {
	mu        sync.Mutex
	turnBase  net.Addr
	relay     net.Addr
	turnHits  int
	relayHits int
}

func (r *transportAddrRecorder) setTURNBase(addr net.Addr) {
	if addr == nil {
		return
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.turnBase = cloneTestAddr(addr)
	r.turnHits++
}

func (r *transportAddrRecorder) setRelay(addr net.Addr) {
	if addr == nil {
		return
	}

	r.mu.Lock()
	defer r.mu.Unlock()
	r.relay = cloneTestAddr(addr)
	r.relayHits++
}

func (r *transportAddrRecorder) TURNBase() net.Addr {
	r.mu.Lock()
	defer r.mu.Unlock()
	return cloneTestAddr(r.turnBase)
}

func (r *transportAddrRecorder) Relay() net.Addr {
	r.mu.Lock()
	defer r.mu.Unlock()
	return cloneTestAddr(r.relay)
}

func (r *transportAddrRecorder) TURNBaseCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.turnHits
}

func (r *transportAddrRecorder) RelayCount() int {
	r.mu.Lock()
	defer r.mu.Unlock()
	return r.relayHits
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

func mustRebindAddr(t *testing.T, addr net.Addr) {
	t.Helper()

	if addr == nil {
		t.Fatal("expected non-nil address for rebind check")
	}

	deadline := time.Now().Add(2 * time.Second)
	for time.Now().Before(deadline) {
		switch value := addr.(type) {
		case *net.UDPAddr:
			conn, err := net.ListenPacket("udp", value.String())
			if err == nil {
				_ = conn.Close()
				return
			}
		case *net.TCPAddr:
			listener, err := net.Listen("tcp", value.String())
			if err == nil {
				_ = listener.Close()
				return
			}
		default:
			t.Fatalf("unsupported addr type %T", addr)
		}

		time.Sleep(20 * time.Millisecond)
	}

	t.Fatalf("rebind %s: address stayed busy past deadline", addr.String())
}

func cloneTestAddr(addr net.Addr) net.Addr {
	switch value := addr.(type) {
	case *net.UDPAddr:
		if value == nil {
			return nil
		}
		cloned := *value
		cloned.IP = append(net.IP(nil), value.IP...)
		return &cloned
	case *net.TCPAddr:
		if value == nil {
			return nil
		}
		cloned := *value
		cloned.IP = append(net.IP(nil), value.IP...)
		return &cloned
	default:
		return addr
	}
}

type transportRestartProbe struct {
	mu        sync.Mutex
	attempts  map[int]int
	readyCh   chan int
	turnBases []net.Addr
	relays    []net.Addr
}

func newTransportRestartProbe() *transportRestartProbe {
	return &transportRestartProbe{
		attempts: make(map[int]int),
		readyCh:  make(chan int, 8),
	}
}

func (p *transportRestartProbe) RunnerFactory() RunnerFactory {
	return func(cfg transport.ClientConfig) transport.Runner {
		attempt := p.nextAttempt(cfg.WorkerIndex)

		previousReady := cfg.Hooks.OnReady
		previousTURNBase := cfg.Hooks.OnTURNBaseBind
		previousRelay := cfg.Hooks.OnRelayAllocate
		cfg.Hooks.OnReady = func() {
			if previousReady != nil {
				previousReady()
			}
			select {
			case p.readyCh <- attempt:
			default:
			}
		}
		cfg.Hooks.OnTURNBaseBind = func(addr net.Addr) {
			if previousTURNBase != nil {
				previousTURNBase(addr)
			}
			p.recordTURNBase(addr)
		}
		cfg.Hooks.OnRelayAllocate = func(addr net.Addr) {
			if previousRelay != nil {
				previousRelay(addr)
			}
			p.recordRelay(addr)
		}

		if cfg.WorkerIndex == 0 && attempt == 0 {
			return failingTransportRunner{cfg: cfg}
		}

		return transport.NewClientRunner(cfg)
	}
}

func (p *transportRestartProbe) nextAttempt(worker int) int {
	p.mu.Lock()
	defer p.mu.Unlock()

	attempt := p.attempts[worker]
	p.attempts[worker] = attempt + 1
	return attempt
}

func (p *transportRestartProbe) recordTURNBase(addr net.Addr) {
	if addr == nil {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	p.turnBases = append(p.turnBases, cloneTestAddr(addr))
}

func (p *transportRestartProbe) recordRelay(addr net.Addr) {
	if addr == nil {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()
	p.relays = append(p.relays, cloneTestAddr(addr))
}

func (p *transportRestartProbe) turnBaseCount() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.turnBases)
}

func (p *transportRestartProbe) relayCount() int {
	p.mu.Lock()
	defer p.mu.Unlock()
	return len(p.relays)
}

func (p *transportRestartProbe) mustWaitReady(t *testing.T, wantAttempt int) {
	t.Helper()

	select {
	case got := <-p.readyCh:
		if got != wantAttempt {
			t.Fatalf("worker ready attempt = %d, want %d", got, wantAttempt)
		}
	case <-time.After(5 * time.Second):
		t.Fatalf("timed out waiting for ready attempt %d", wantAttempt)
	}
}

type failingTransportRunner struct {
	cfg transport.ClientConfig
}

func (r failingTransportRunner) Run(ctx context.Context) error {
	if r.cfg.Outbound == nil {
		return transport.NewClientRunner(r.cfg).Run(ctx)
	}

	proxyOutbound := make(chan transport.RelayPacket, 1)
	cfg := r.cfg
	cfg.Outbound = proxyOutbound

	go func() {
		defer close(proxyOutbound)
		for {
			select {
			case <-ctx.Done():
				return
			case packet, ok := <-r.cfg.Outbound:
				if !ok {
					return
				}
				select {
				case proxyOutbound <- packet:
				case <-ctx.Done():
					return
				}

				return
			}
		}
	}()

	return transport.NewClientRunner(cfg).Run(ctx)
}
