package session

import (
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

func TestBuildTransportPlanSupportsExpandedMatrix(t *testing.T) {
	testCases := []struct {
		name         string
		mode         config.TransportMode
		useDTLS      bool
		bindTarget   string
		wantMode     config.TransportMode
		wantTURNMode transport.TURNMode
		wantPeerMode transport.PeerMode
		wantBindIP   string
	}{
		{
			name:         "auto-dtls",
			mode:         config.TransportModeAuto,
			useDTLS:      true,
			wantMode:     config.TransportModeUDP,
			wantTURNMode: transport.TURNModeUDP,
			wantPeerMode: transport.PeerModeDTLS,
		},
		{
			name:         "tcp-dtls",
			mode:         config.TransportModeTCP,
			useDTLS:      true,
			wantMode:     config.TransportModeTCP,
			wantTURNMode: transport.TURNModeTCP,
			wantPeerMode: transport.PeerModeDTLS,
		},
		{
			name:         "udp-plain",
			mode:         config.TransportModeUDP,
			useDTLS:      false,
			wantMode:     config.TransportModeUDP,
			wantTURNMode: transport.TURNModeUDP,
			wantPeerMode: transport.PeerModePlain,
		},
		{
			name:         "tcp-plain-with-bind",
			mode:         config.TransportModeTCP,
			useDTLS:      false,
			bindTarget:   "127.0.0.1",
			wantMode:     config.TransportModeTCP,
			wantTURNMode: transport.TURNModeTCP,
			wantPeerMode: transport.PeerModePlain,
			wantBindIP:   "127.0.0.1",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			plan, err := buildTransportPlan(config.ClientConfig{
				Connections:   1,
				Mode:          tc.mode,
				UseDTLS:       tc.useDTLS,
				BindInterface: tc.bindTarget,
			})
			if err != nil {
				t.Fatalf("buildTransportPlan() error = %v", err)
			}
			if plan.Mode != tc.wantMode {
				t.Fatalf("plan.Mode = %s, want %s", plan.Mode, tc.wantMode)
			}
			if plan.TURNMode != tc.wantTURNMode {
				t.Fatalf("plan.TURNMode = %s, want %s", plan.TURNMode, tc.wantTURNMode)
			}
			if plan.PeerMode != tc.wantPeerMode {
				t.Fatalf("plan.PeerMode = %s, want %s", plan.PeerMode, tc.wantPeerMode)
			}

			gotBindIP := ""
			if plan.BindIP != nil {
				gotBindIP = plan.BindIP.String()
			}
			if gotBindIP != tc.wantBindIP {
				t.Fatalf("plan.BindIP = %q, want %q", gotBindIP, tc.wantBindIP)
			}
		})
	}
}

func TestBuildTransportPlanRejectsNonIPBindInterface(t *testing.T) {
	_, err := buildTransportPlan(config.ClientConfig{
		Connections:   1,
		Mode:          config.TransportModeUDP,
		UseDTLS:       true,
		BindInterface: "eth0",
	})
	if err == nil {
		t.Fatal("expected error")
	}
}

func TestBuildSessionPlanCarriesSupervisionPolicy(t *testing.T) {
	plan, err := buildSessionPlan(config.ClientConfig{
		Connections: 3,
		Mode:        config.TransportModeUDP,
		UseDTLS:     true,
	}, Dependencies{
		RestartBackoff:    50,
		MaxWorkerRestarts: 2,
	})
	if err != nil {
		t.Fatalf("buildSessionPlan() error = %v", err)
	}
	if plan.Connections != 3 {
		t.Fatalf("plan.Connections = %d, want 3", plan.Connections)
	}
	if plan.RestartBackoff != 50 {
		t.Fatalf("plan.RestartBackoff = %s, want 50ns", plan.RestartBackoff)
	}
	if plan.MaxWorkerRestarts != 2 {
		t.Fatalf("plan.MaxWorkerRestarts = %d, want 2", plan.MaxWorkerRestarts)
	}
	if plan.Transport.TURNMode != transport.TURNModeUDP {
		t.Fatalf("plan.Transport.TURNMode = %s, want %s", plan.Transport.TURNMode, transport.TURNModeUDP)
	}
}
