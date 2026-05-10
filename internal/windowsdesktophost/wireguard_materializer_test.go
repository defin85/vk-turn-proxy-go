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
		"MTU = 1412",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"PresharedKey = peer-preshared-key",
		"AllowedIPs = 0.0.0.0/1, 128.0.0.0/1",
		"Endpoint = relay.example.test:3478",
		"PersistentKeepalive = 21",
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
			RemoteEndpointRole:   clientcontrol.RuntimeRemoteEndpointRoleWireGuardRawDatagram,
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
	if lease.MTU != 1412 {
		t.Fatalf("lease.MTU = %d, want 1412", lease.MTU)
	}
	if lease.PresharedKey != "peer-preshared-key" {
		t.Fatalf("lease.PresharedKey = %q, want peer-preshared-key", lease.PresharedKey)
	}
	if lease.PersistentKeepaliveSeconds != 21 {
		t.Fatalf("lease.PersistentKeepaliveSeconds = %d, want 21", lease.PersistentKeepaliveSeconds)
	}
}

func TestDefaultWindowsWireGuardTurnMaterializerRejectsProfileWithoutRawIngressEndpoint(t *testing.T) {
	profilePath := filepath.Join(t.TempDir(), "desktop1-windows.conf")
	profileContents := strings.Join([]string{
		"[Interface]",
		"PrivateKey = client-private-key",
		"Address = 10.10.0.2/32",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"AllowedIPs = 0.0.0.0/0",
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
	_, err = materializer(context.Background(), clientcontrol.WireGuardTurnMaterializeRequest{
		ResolutionID: "resolution-windows-1",
		Descriptor: clientcontrol.RuntimeExecutionPlanDescriptor{
			Plan: clientcontrol.RuntimeExecutionPlan{
				AccessMethod:  clientcontrol.RuntimeAccessMethodTURNCredentials,
				CarrierFamily: clientcontrol.RuntimeCarrierFamilyTURNDatagram,
				EngineFamily:  clientcontrol.RuntimeEngineFamilyWireGuardNative,
				HostAdapter:   clientcontrol.RuntimeHostAdapterWindowsWintun,
			},
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   clientcontrol.RuntimeRemoteEndpointRoleWireGuardRawDatagram,
		},
		Credentials: provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		Defaults: clientcontrol.RuntimeDefaults{PeerAddr: "dtls-only.example.test:56040"},
	})
	if err == nil {
		t.Fatal("materializer() error = nil, want explicit raw ingress endpoint failure")
	}
	if !strings.Contains(err.Error(), "explicit raw WireGuard ingress endpoint") {
		t.Fatalf("materializer() error = %v, want raw-ingress endpoint detail", err)
	}
}

func TestWindowsWireGuardEnvPathMigratesIntoTransportProfileStore(t *testing.T) {
	profilePath := filepath.Join(t.TempDir(), "desktop1-windows.conf")
	storePath := filepath.Join(t.TempDir(), "vpn-transport-profiles", "store.json")
	profileContents := strings.Join([]string{
		"[Interface]",
		"PrivateKey = client-private-key",
		"Address = 10.10.0.2/32",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"AllowedIPs = 0.0.0.0/0",
		"Endpoint = relay.example.test:3478",
		"",
	}, "\n")
	if err := os.WriteFile(profilePath, []byte(profileContents), 0o600); err != nil {
		t.Fatalf("write profile: %v", err)
	}
	t.Setenv(windowsWireGuardProfileEnv, profilePath)
	t.Setenv(windowsTransportProfileStoreEnv, storePath)

	host := NewClientControlHost(nil)
	info := host.Info()
	found := false
	for _, capability := range info.Capabilities {
		if capability == clientcontrol.CapabilityVPNTransportProfileStore {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("capabilities = %v, want VPN transport profile store support", info.Capabilities)
	}
	if info.TransportProfileStore == nil {
		t.Fatal("transport_profile_store = nil, want Windows host to advertise transport-profile store support")
	}
	profiles, err := host.TransportProfiles()
	if err != nil {
		t.Fatalf("TransportProfiles() error = %v", err)
	}
	if len(profiles) != 1 {
		t.Fatalf("TransportProfiles() len = %d, want 1 migrated profile", len(profiles))
	}
	if profiles[0].SecretMaterialRef.Kind != clientcontrol.TransportProfileMaterialSourceLegacyPath {
		t.Fatalf("secret material source = %q, want %q", profiles[0].SecretMaterialRef.Kind, clientcontrol.TransportProfileMaterialSourceLegacyPath)
	}
	if profiles[0].Validation.State != clientcontrol.TransportProfileValidationStateValid {
		t.Fatalf("validation state = %s, want valid", profiles[0].Validation.State)
	}
}
