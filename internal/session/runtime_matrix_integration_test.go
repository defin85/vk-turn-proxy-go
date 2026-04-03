package session

import (
	"context"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
	"github.com/defin85/vk-turn-proxy-go/test/turnlab"
)

const loopbackBindTarget = "127.0.0.2"

func TestRunRelayRoundTripOverTCPDTLS(t *testing.T) {
	harness := startRuntimeHarness(t)
	mustRunRoundTrip(t, runtimeScenario{
		link:     harness.Descriptor.GenericTurnTCPLink(),
		peerAddr: harness.Descriptor.PeerAddress,
		mode:     config.TransportModeTCP,
		useDTLS:  true,
		bindIP:   "",
		wantEcho: []byte("tcp-dtls-round-trip"),
	})
}

func TestRunPlainRelayRoundTripUDP(t *testing.T) {
	harness := startRuntimeHarness(t)
	mustRunRoundTrip(t, runtimeScenario{
		link:     harness.GenericTurnLink(),
		peerAddr: harness.Descriptor.UpstreamAddress,
		mode:     config.TransportModeUDP,
		useDTLS:  false,
		bindIP:   "",
		wantEcho: []byte("udp-plain-round-trip"),
	})
}

func TestRunPlainRelayRoundTripTCP(t *testing.T) {
	harness := startRuntimeHarness(t)
	mustRunRoundTrip(t, runtimeScenario{
		link:     harness.Descriptor.GenericTurnTCPLink(),
		peerAddr: harness.Descriptor.UpstreamAddress,
		mode:     config.TransportModeTCP,
		useDTLS:  false,
		bindIP:   "",
		wantEcho: []byte("tcp-plain-round-trip"),
	})
}

func TestRunPlainRelayRoundTripAuto(t *testing.T) {
	harness := startRuntimeHarness(t)
	mustRunRoundTrip(t, runtimeScenario{
		link:     harness.GenericTurnLink(),
		peerAddr: harness.Descriptor.UpstreamAddress,
		mode:     config.TransportModeAuto,
		useDTLS:  false,
		bindIP:   "",
		wantEcho: []byte("auto-plain-round-trip"),
	})
}

func TestRunAppliesBindTargetToTURNTransport(t *testing.T) {
	harness := startRuntimeHarness(t)

	testCases := []struct {
		name string
		link string
		mode config.TransportMode
	}{
		{
			name: "auto",
			link: harness.GenericTurnLink(),
			mode: config.TransportModeAuto,
		},
		{
			name: "udp",
			link: harness.GenericTurnLink(),
			mode: config.TransportModeUDP,
		},
		{
			name: "tcp",
			link: harness.Descriptor.GenericTurnTCPLink(),
			mode: config.TransportModeTCP,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			recorder := &transportAddrRecorder{}
			listenAddr := reserveUDPAddr(t)
			ctx, cancel := context.WithCancel(context.Background())
			errCh := make(chan error, 1)

			go func() {
				errCh <- Run(ctx, config.ClientConfig{
					Provider:      "generic-turn",
					Link:          tc.link,
					ListenAddr:    listenAddr,
					PeerAddr:      harness.Descriptor.PeerAddress,
					Connections:   1,
					Mode:          tc.mode,
					UseDTLS:       true,
					BindInterface: loopbackBindTarget,
				}, Dependencies{
					Registry:  provider.NewRegistry(genericturn.New()),
					Logger:    testLogger(),
					NewRunner: recorder.RunnerFactory(),
					SessionID: NewID(),
				})
			}()

			clientConn, err := net.Dial("udp", listenAddr)
			if err != nil {
				cancel()
				t.Fatalf("dial local client addr: %v", err)
			}
			t.Cleanup(func() { _ = clientConn.Close() })

			mustEchoEventually(t, clientConn, []byte(tc.name+"-bind"))

			turnBase := recorder.TURNBase()
			if turnBase == nil {
				cancel()
				t.Fatal("turn base address was not recorded")
			}
			if got := addrIPString(turnBase); got != loopbackBindTarget {
				cancel()
				t.Fatalf("turn base ip = %s, want %s", got, loopbackBindTarget)
			}

			cancel()
			select {
			case err := <-errCh:
				if err != nil {
					t.Fatalf("Run() error = %v", err)
				}
			case <-time.After(5 * time.Second):
				t.Fatal("session did not stop after cancellation")
			}
		})
	}
}

func TestRunFailsOnInvalidPeerAddress(t *testing.T) {
	harness := startRuntimeHarness(t)
	recorder := &transportAddrRecorder{}
	listenAddr := reserveUDPAddr(t)

	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	err := Run(ctx, config.ClientConfig{
		Provider:    "generic-turn",
		Link:        harness.GenericTurnLink(),
		ListenAddr:  listenAddr,
		PeerAddr:    "bad-peer",
		Connections: 1,
		Mode:        config.TransportModeUDP,
		UseDTLS:     false,
	}, Dependencies{
		Registry:  provider.NewRegistry(genericturn.New()),
		Logger:    testLogger(),
		NewRunner: recorder.RunnerFactory(),
		SessionID: NewID(),
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.PeerSetup {
		t.Fatalf("unexpected stage: %v", err)
	}
	mustRebindPacket(t, listenAddr)
	mustRebindAddr(t, recorder.TURNBase())
	mustRebindAddr(t, recorder.Relay())
}

func TestRunFailsOnBadTURNCredentialsOverTCP(t *testing.T) {
	harness := startRuntimeHarness(t)
	recorder := &transportAddrRecorder{}
	listenAddr := reserveUDPAddr(t)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	badLink := strings.Replace(harness.Descriptor.GenericTurnTCPLink(), "turn-lab-pass", "wrong-pass", 1)
	err := Run(ctx, config.ClientConfig{
		Provider:    "generic-turn",
		Link:        badLink,
		ListenAddr:  listenAddr,
		PeerAddr:    harness.Descriptor.PeerAddress,
		Connections: 1,
		Mode:        config.TransportModeTCP,
		UseDTLS:     true,
	}, Dependencies{
		Registry:  provider.NewRegistry(genericturn.New()),
		Logger:    testLogger(),
		NewRunner: recorder.RunnerFactory(),
		SessionID: NewID(),
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.TURNAllocate {
		t.Fatalf("unexpected stage: %v", err)
	}
	mustRebindPacket(t, listenAddr)
	waitCtx, waitCancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer waitCancel()
	if err := harness.WaitNoActiveTURNTCPConns(waitCtx); err != nil {
		t.Fatalf("wait for turn tcp cleanup: %v", err)
	}
}

func TestRunFailsOnBadDTLSPeerOverTCP(t *testing.T) {
	harness := startRuntimeHarness(t)
	recorder := &transportAddrRecorder{}
	listenAddr := reserveUDPAddr(t)

	plainPeer, err := net.ListenPacket("udp4", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen plain udp peer: %v", err)
	}
	t.Cleanup(func() {
		_ = plainPeer.Close()
	})

	ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
	defer cancel()

	err = Run(ctx, config.ClientConfig{
		Provider:    "generic-turn",
		Link:        harness.Descriptor.GenericTurnTCPLink(),
		ListenAddr:  listenAddr,
		PeerAddr:    plainPeer.LocalAddr().String(),
		Connections: 1,
		Mode:        config.TransportModeTCP,
		UseDTLS:     true,
	}, Dependencies{
		Registry:  provider.NewRegistry(genericturn.New()),
		Logger:    testLogger(),
		NewRunner: recorder.RunnerFactory(),
		SessionID: NewID(),
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.DTLSHandshake {
		t.Fatalf("unexpected stage: %v", err)
	}
	mustRebindPacket(t, listenAddr)
	mustRebindAddr(t, recorder.Relay())
	waitCtx, waitCancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer waitCancel()
	if err := harness.WaitNoActiveTURNTCPConns(waitCtx); err != nil {
		t.Fatalf("wait for turn tcp cleanup: %v", err)
	}
}

func TestRunFailsOnUnappliableBindTarget(t *testing.T) {
	harness := startRuntimeHarness(t)

	testCases := []struct {
		name string
		link string
		mode config.TransportMode
	}{
		{
			name: "udp",
			link: harness.GenericTurnLink(),
			mode: config.TransportModeUDP,
		},
		{
			name: "tcp",
			link: harness.Descriptor.GenericTurnTCPLink(),
			mode: config.TransportModeTCP,
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			listenAddr := reserveUDPAddr(t)
			ctx, cancel := context.WithTimeout(context.Background(), 6*time.Second)
			defer cancel()

			err := Run(ctx, config.ClientConfig{
				Provider:      "generic-turn",
				Link:          tc.link,
				ListenAddr:    listenAddr,
				PeerAddr:      harness.Descriptor.PeerAddress,
				Connections:   1,
				Mode:          tc.mode,
				UseDTLS:       true,
				BindInterface: "198.51.100.10",
			}, Dependencies{
				Registry:  provider.NewRegistry(genericturn.New()),
				Logger:    testLogger(),
				SessionID: NewID(),
			})
			if err == nil {
				t.Fatal("expected error")
			}
			stage, ok := runstage.FromError(err)
			if !ok || stage != runstage.TURNDial {
				t.Fatalf("unexpected stage: %v", err)
			}
			mustRebindPacket(t, listenAddr)
		})
	}
}

type runtimeScenario struct {
	link     string
	peerAddr string
	mode     config.TransportMode
	useDTLS  bool
	bindIP   string
	wantEcho []byte
}

func startRuntimeHarness(t *testing.T) *turnlab.Harness {
	t.Helper()

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

	return harness
}

func mustRunRoundTrip(t *testing.T, scenario runtimeScenario) {
	t.Helper()

	sessionCtx, cancelSession := context.WithCancel(context.Background())
	errCh := make(chan error, 1)
	listenAddr := reserveUDPAddr(t)

	go func() {
		errCh <- Run(sessionCtx, config.ClientConfig{
			Provider:      "generic-turn",
			Link:          scenario.link,
			ListenAddr:    listenAddr,
			PeerAddr:      scenario.peerAddr,
			Connections:   1,
			Mode:          scenario.mode,
			UseDTLS:       scenario.useDTLS,
			BindInterface: scenario.bindIP,
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
	t.Cleanup(func() { _ = clientConn.Close() })

	mustEchoEventually(t, clientConn, scenario.wantEcho)

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

func addrIPString(addr net.Addr) string {
	switch value := addr.(type) {
	case *net.UDPAddr:
		return value.IP.String()
	case *net.TCPAddr:
		return value.IP.String()
	default:
		return ""
	}
}

func (r *transportAddrRecorder) RunnerFactory() RunnerFactory {
	return func(cfg transport.ClientConfig) transport.Runner {
		previousTURNBase := cfg.Hooks.OnTURNBaseBind
		previousRelayAllocate := cfg.Hooks.OnRelayAllocate
		cfg.Hooks.OnTURNBaseBind = func(addr net.Addr) {
			if previousTURNBase != nil {
				previousTURNBase(addr)
			}
			r.setTURNBase(addr)
		}
		cfg.Hooks.OnRelayAllocate = func(addr net.Addr) {
			if previousRelayAllocate != nil {
				previousRelayAllocate(addr)
			}
			r.setRelay(addr)
		}

		return transport.NewClientRunner(cfg)
	}
}
