package windowsdesktophost

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestDefaultWindowsWireGuardTurnMaterializerRequiresValidProfile(t *testing.T) {
	t.Setenv(windowsWireGuardProfileEnv, filepath.Join(t.TempDir(), "missing.conf"))

	materializer, err := defaultWindowsWireGuardTurnMaterializer()
	if err == nil {
		t.Fatal("defaultWindowsWireGuardTurnMaterializer() error = nil, want missing profile error")
	}
	if materializer != nil {
		t.Fatal("defaultWindowsWireGuardTurnMaterializer() materializer != nil, want nil on missing profile")
	}
	if !strings.Contains(err.Error(), "does not exist") {
		t.Fatalf("defaultWindowsWireGuardTurnMaterializer() error = %v, want missing-profile detail", err)
	}
}

func TestDefaultWindowsWireGuardTurnMaterializerLoadsValidatedProfile(t *testing.T) {
	profilePath := filepath.Join(t.TempDir(), "desktop1-windows.conf")
	profileContents := strings.Join([]string{
		"[Interface]",
		"PrivateKey = client-private-key",
		"Address = 10.10.0.2/32",
		"DNS = 1.1.1.1, 8.8.8.8",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"AllowedIPs = 0.0.0.0/1, 128.0.0.0/1",
		"Endpoint = relay.example.test:3478",
		"",
	}, "\n")
	if err := os.WriteFile(profilePath, []byte(profileContents), 0o600); err != nil {
		t.Fatalf("write profile: %v", err)
	}
	t.Setenv(windowsWireGuardProfileEnv, profilePath)

	materializer, err := defaultWindowsWireGuardTurnMaterializer()
	if err != nil {
		t.Fatalf("defaultWindowsWireGuardTurnMaterializer() error = %v", err)
	}
	if materializer == nil {
		t.Fatal("defaultWindowsWireGuardTurnMaterializer() materializer = nil, want materializer")
	}

	lease, err := materializer(context.Background(), clientcontrol.WireGuardTurnMaterializeRequest{
		ResolutionID: "resolution-windows-1",
		Descriptor: clientcontrol.RuntimeExecutionPlanDescriptor{
			Plan: clientcontrol.RuntimeExecutionPlan{
				AccessMethod:  clientcontrol.RuntimeAccessMethodTURNCredentials,
				CarrierFamily: clientcontrol.RuntimeCarrierFamilyTURNDatagram,
				EngineFamily:  clientcontrol.RuntimeEngineFamilyWireGuardNative,
				HostAdapter:   clientcontrol.RuntimeHostAdapterWindowsWintun,
			},
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
		},
		Credentials: provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		Defaults: clientcontrol.RuntimeDefaults{},
	})
	if err != nil {
		t.Fatalf("materializer() error = %v", err)
	}
	if lease == nil {
		t.Fatal("materializer() lease = nil, want lease")
	}
	if lease.PeerEndpointAddress != "relay.example.test:3478" {
		t.Fatalf("lease.PeerEndpointAddress = %q, want relay.example.test:3478", lease.PeerEndpointAddress)
	}
	if len(lease.DNSServers) != 2 {
		t.Fatalf("lease.DNSServers len = %d, want 2", len(lease.DNSServers))
	}
	if len(lease.AllowedIPs) != 2 {
		t.Fatalf("lease.AllowedIPs len = %d, want 2", len(lease.AllowedIPs))
	}
}
