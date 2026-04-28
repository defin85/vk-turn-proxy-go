package androidembeddedhost

import (
	"context"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestDefaultAndroidWireGuardTurnMaterializerRequiresExplicitProfilePath(t *testing.T) {
	SetAndroidWireGuardProfilePath("")
	t.Cleanup(func() { SetAndroidWireGuardProfilePath("") })

	materializer := defaultAndroidWireGuardTurnMaterializer()
	if materializer == nil {
		t.Fatal("defaultAndroidWireGuardTurnMaterializer() = nil, want dynamic materializer")
	}

	_, err := materializer(context.Background(), androidWireGuardMaterializeRequest())
	if err == nil {
		t.Fatal("materializer() error = nil, want explicit profile error")
	}
	if !strings.Contains(err.Error(), "explicit Android WireGuard profile is not configured") {
		t.Fatalf("materializer() error = %v, want explicit profile detail", err)
	}
}

func TestDefaultAndroidWireGuardTurnMaterializerLoadsExplicitProfilePath(t *testing.T) {
	profilePath := filepath.Join(t.TempDir(), "android-vpn-service.conf")
	profileContents := strings.Join([]string{
		"[Interface]",
		"PrivateKey = client-private-key",
		"Address = 10.10.0.2/32",
		"DNS = 1.1.1.1",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"AllowedIPs = 0.0.0.0/0",
		"Endpoint = relay.example.test:51820",
		"",
	}, "\n")
	if err := os.WriteFile(profilePath, []byte(profileContents), 0o600); err != nil {
		t.Fatalf("write profile: %v", err)
	}
	SetAndroidWireGuardProfilePath(profilePath)
	t.Cleanup(func() { SetAndroidWireGuardProfilePath("") })

	lease, err := defaultAndroidWireGuardTurnMaterializer()(
		context.Background(),
		androidWireGuardMaterializeRequest(),
	)
	if err != nil {
		t.Fatalf("materializer() error = %v", err)
	}
	if lease.ClientPrivateKey != "client-private-key" {
		t.Fatalf("lease.ClientPrivateKey = %q, want client-private-key", lease.ClientPrivateKey)
	}
	if lease.PeerEndpointAddress != "relay.example.test:51820" {
		t.Fatalf("lease.PeerEndpointAddress = %q, want relay.example.test:51820", lease.PeerEndpointAddress)
	}
}

func androidWireGuardMaterializeRequest() clientcontrol.WireGuardTurnMaterializeRequest {
	return clientcontrol.WireGuardTurnMaterializeRequest{
		ResolutionID: "resolution-android-1",
		Descriptor: clientcontrol.RuntimeExecutionPlanDescriptor{
			Plan: clientcontrol.RuntimeExecutionPlan{
				AccessMethod:  clientcontrol.RuntimeAccessMethodTURNCredentials,
				CarrierFamily: clientcontrol.RuntimeCarrierFamilyTURNDatagram,
				EngineFamily:  clientcontrol.RuntimeEngineFamilyWireGuardNative,
				HostAdapter:   clientcontrol.RuntimeHostAdapterAndroidVPNService,
			},
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
		},
		Credentials: provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		Defaults: clientcontrol.RuntimeDefaults{},
	}
}
