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
		"MTU = 1412",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"PresharedKey = peer-preshared-key",
		"AllowedIPs = 0.0.0.0/0",
		"Endpoint = relay.example.test:51820",
		"PersistentKeepalive = 21",
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
	if len(lease.DNSServers) != 1 || lease.DNSServers[0] != "1.1.1.1" {
		t.Fatalf("lease.DNSServers = %+v, want [1.1.1.1]", lease.DNSServers)
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

func TestDefaultAndroidWireGuardTurnMaterializerRejectsProfileWithoutRawIngressEndpoint(t *testing.T) {
	profilePath := filepath.Join(t.TempDir(), "android-vpn-service.conf")
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
	SetAndroidWireGuardProfilePath(profilePath)
	t.Cleanup(func() { SetAndroidWireGuardProfilePath("") })

	req := androidWireGuardMaterializeRequest()
	req.Defaults = clientcontrol.RuntimeDefaults{PeerAddr: "dtls-only.example.test:56040"}
	_, err := defaultAndroidWireGuardTurnMaterializer()(context.Background(), req)
	if err == nil {
		t.Fatal("materializer() error = nil, want explicit raw ingress endpoint failure")
	}
	if !strings.Contains(err.Error(), "explicit raw WireGuard ingress endpoint") {
		t.Fatalf("materializer() error = %v, want raw-ingress endpoint detail", err)
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
			RemoteEndpointRole:   clientcontrol.RuntimeRemoteEndpointRoleWireGuardRawDatagram,
		},
		Credentials: provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		Defaults: clientcontrol.RuntimeDefaults{},
	}
}
