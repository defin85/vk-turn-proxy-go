//go:build linux

package linuxdesktophost

import (
	"context"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardturnruntime"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
	"golang.zx2c4.com/wireguard/tun"
)

func TestLinuxTunPackagedTargetGateKeepsUnsupportedTargetsClosed(t *testing.T) {
	t.Parallel()

	build := clientcontrol.BuildIdentity{Target: "linux/amd64"}
	tests := []struct {
		name       string
		target     string
		wantClosed bool
		wantText   string
	}{
		{
			name:       "missing packaged target",
			target:     "",
			wantClosed: true,
			wantText:   "package/install surface",
		},
		{
			name:       "ubuntu package target",
			target:     "ubuntu",
			wantClosed: false,
		},
		{
			name:       "unsupported package target",
			target:     "debian",
			wantClosed: true,
			wantText:   "not supported",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()
			failure := linuxTunPackagedTargetFailure(build, tt.target)
			if tt.wantClosed {
				if failure == nil {
					t.Fatal("linuxTunPackagedTargetFailure() = nil, want fail-closed")
				}
				if failure.prerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
					t.Fatalf(
						"prerequisite = %q, want %q",
						failure.prerequisite,
						clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
					)
				}
				if !strings.Contains(failure.Error(), tt.wantText) {
					t.Fatalf("failure message = %q, want %q", failure.Error(), tt.wantText)
				}
				return
			}
			if failure != nil {
				t.Fatalf("linuxTunPackagedTargetFailure() = %v, want nil", failure)
			}
		})
	}
}

func TestLinuxTunLifecycleConcreteReadyPathUsesHostPrimitives(t *testing.T) {
	ctx := context.Background()
	resolvConfPath := filepath.Join(t.TempDir(), "resolv.conf")
	if err := os.WriteFile(resolvConfPath, []byte("nameserver 9.9.9.9\nnameserver 127.0.0.53\n"), 0o600); err != nil {
		t.Fatalf("write resolv.conf fixture: %v", err)
	}
	runner := &fakeLinuxCommandRunner{
		outputs: map[string]string{
			"ip -4 route show default": "default via 192.0.2.1 dev eth0 proto dhcp src 192.0.2.55 metric 100\n",
			"resolvectl dns eth0":      "Link 2 (eth0): 1.1.1.1\n",
		},
	}
	tunDevice := newFakeLinuxTunDevice("rdtun0", linuxTunDefaultMTU)
	runtime := &fakeLinuxRuntime{
		stats: []wireguardturnruntime.PeerStats{
			{
				LastHandshakeTime: time.Now().UTC().Add(-10 * time.Second),
				RxBytes:           100,
				TxBytes:           200,
			},
			{
				LastHandshakeTime: time.Now().UTC(),
				RxBytes:           900,
				TxBytes:           700,
			},
		},
	}
	var createdName string
	var createdMTU int
	lifecycle := &linuxTunLifecycle{
		runner:         runner,
		resolvConfPath: resolvConfPath,
		probeURL:       "http://probe.test/cdn-cgi/trace",
		euid:           func() int { return 0 },
		tun: func(name string, mtu int) (tun.Device, error) {
			createdName = name
			createdMTU = mtu
			return tunDevice, nil
		},
		runtimeStarter: func(_ context.Context, lease *clientcontrol.WireGuardTurnExecutionLease, device tun.Device) (linuxWireGuardRuntime, error) {
			if lease == nil {
				t.Fatal("runtime starter lease = nil")
			}
			if device != tunDevice {
				t.Fatalf("runtime starter device = %p, want %p", device, tunDevice)
			}
			return runtime, nil
		},
		httpClient: &http.Client{
			Transport: roundTripFunc(func(req *http.Request) (*http.Response, error) {
				if req.URL.String() != "http://probe.test/cdn-cgi/trace" {
					t.Fatalf("probe URL = %q, want fixture URL", req.URL.String())
				}
				return &http.Response{
					StatusCode: http.StatusOK,
					Status:     "200 OK",
					Body:       io.NopCloser(strings.NewReader("ip=198.51.100.7\n")),
					Header:     make(http.Header),
					Request:    req,
				}, nil
			}),
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(func(
		context.Context,
		clientcontrol.PlatformTunnelStartRequest,
		*clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		return &clientcontrol.WireGuardTurnExecutionLease{
			ResolutionID:         "resolution-ubuntu",
			AccessMethod:         clientcontrol.RuntimeAccessMethodTURNCredentials,
			CarrierFamily:        clientcontrol.RuntimeCarrierFamilyTURNDatagram,
			EngineFamily:         clientcontrol.RuntimeEngineFamilyWireGuardNative,
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   clientcontrol.WireGuardTurnRemoteEndpointRoleDatagramTermination,
			TURNServerAddress:    "203.0.113.10:3478",
			TURNUsername:         "user",
			TURNPassword:         "pass",
			PeerEndpointAddress:  "198.51.100.7:56042",
			ClientPrivateKey:     "client-key",
			ClientAddresses:      []string{"10.10.0.2/32", "fd00::2/128"},
			PeerPublicKey:        "peer-key",
			AllowedIPs:           []string{"0.0.0.0/0", "::/0"},
			MTU:                  1420,
		}, nil
	})

	result, err := controller.Start(ctx, clientcontrol.PlatformTunnelStartRequest{
		Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID:        "resolution-ubuntu",
		UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if !result.Ready {
		t.Fatalf("Start().Ready = false, want true: %+v", result)
	}
	if createdName != linuxTunInterfaceName {
		t.Fatalf("created TUN name = %q, want %q", createdName, linuxTunInterfaceName)
	}
	if createdMTU != linuxTunDefaultMTU {
		t.Fatalf("created TUN MTU = %d, want %d", createdMTU, linuxTunDefaultMTU)
	}
	for _, excluded := range []string{"1.1.1.1", "9.9.9.9", "203.0.113.10"} {
		if !containsString(result.UnderlayRouteExclusions, excluded) {
			t.Fatalf("UnderlayRouteExclusions = %v, want %s", result.UnderlayRouteExclusions, excluded)
		}
	}
	for _, command := range []string{
		"ip link set dev rdtun0 up mtu 1420",
		"ip address replace 10.10.0.2/32 dev rdtun0",
		"ip route replace 0.0.0.0/1 dev rdtun0 metric 0",
		"ip route replace 128.0.0.0/1 dev rdtun0 metric 0",
		"ip route replace 203.0.113.10/32 via 192.0.2.1 dev eth0 metric 1",
	} {
		if !runner.hasCommand(command) {
			t.Fatalf("commands = %v, want %q", runner.commands, command)
		}
	}
	if result.Dataplane == nil || !result.Dataplane.BidirectionalTrafficVerified {
		t.Fatalf("Start().Dataplane = %+v, want verified bidirectional evidence", result.Dataplane)
	}
	if result.Dataplane.RemoteEgressIP != "198.51.100.7" {
		t.Fatalf("RemoteEgressIP = %q, want 198.51.100.7", result.Dataplane.RemoteEgressIP)
	}

	stop, err := controller.Stop(ctx, clientcontrol.PlatformTunnelStopRequest{Mode: clientcontrol.PlatformTunnelModeLinuxTun})
	if err != nil {
		t.Fatalf("Stop() error = %v", err)
	}
	if !stop.Stopped {
		t.Fatalf("Stop().Stopped = false, want true: %+v", stop)
	}
	if !runtime.closed {
		t.Fatal("runtime closed = false, want true")
	}
	if !tunDevice.closed {
		t.Fatal("tun device closed = false, want true")
	}
	for _, command := range []string{
		"ip route del 0.0.0.0/1 dev rdtun0",
		"ip route del 128.0.0.0/1 dev rdtun0",
		"ip address flush dev rdtun0",
		"ip link set dev rdtun0 down",
	} {
		if !runner.hasCommand(command) {
			t.Fatalf("commands = %v, want cleanup command %q", runner.commands, command)
		}
	}
}

func TestLinuxTunLifecycleRouteValidationFailsClosedWithoutDNSBypass(t *testing.T) {
	lifecycle := &linuxTunLifecycle{
		runner: &fakeLinuxCommandRunner{
			outputs: map[string]string{
				"ip -4 route show default": "default via 192.0.2.1 dev eth0 proto dhcp src 192.0.2.55 metric 100\n",
			},
		},
		resolvConfPath: filepath.Join(t.TempDir(), "missing-resolv.conf"),
	}

	_, err := lifecycle.ValidateRoutePolicy(
		context.Background(),
		clientcontrol.PlatformTunnelStartRequest{
			Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		},
		nil,
		&clientcontrol.WireGuardTurnExecutionLease{TURNServerAddress: "203.0.113.10:3478"},
	)
	if err == nil {
		t.Fatal("ValidateRoutePolicy() error = nil, want DNS bypass failure")
	}
	var routeErr *linuxTunRoutePolicyError
	if !errors.As(err, &routeErr) {
		t.Fatalf("ValidateRoutePolicy() error = %v, want linuxTunRoutePolicyError", err)
	}
	if routeErr.prerequisite != clientcontrol.PlatformTunnelPrerequisiteDNSBypass {
		t.Fatalf(
			"route prerequisite = %q, want %q",
			routeErr.prerequisite,
			clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
		)
	}
}

type fakeLinuxCommandRunner struct {
	outputs  map[string]string
	commands []string
}

func (f *fakeLinuxCommandRunner) Run(_ context.Context, name string, args ...string) ([]byte, error) {
	command := strings.TrimSpace(name + " " + strings.Join(args, " "))
	f.commands = append(f.commands, command)
	return []byte(f.outputs[command]), nil
}

func (f *fakeLinuxCommandRunner) hasCommand(command string) bool {
	for _, got := range f.commands {
		if got == command {
			return true
		}
	}
	return false
}

type fakeLinuxRuntime struct {
	stats  []wireguardturnruntime.PeerStats
	calls  int
	closed bool
}

func (f *fakeLinuxRuntime) PeerStats() (wireguardturnruntime.PeerStats, error) {
	if len(f.stats) == 0 {
		return wireguardturnruntime.PeerStats{}, nil
	}
	if f.calls >= len(f.stats) {
		return f.stats[len(f.stats)-1], nil
	}
	stats := f.stats[f.calls]
	f.calls++
	return stats, nil
}

func (f *fakeLinuxRuntime) Close() error {
	f.closed = true
	return nil
}

type fakeLinuxTunDevice struct {
	name   string
	mtu    int
	events chan tun.Event
	closed bool
}

func newFakeLinuxTunDevice(name string, mtu int) *fakeLinuxTunDevice {
	return &fakeLinuxTunDevice{
		name:   name,
		mtu:    mtu,
		events: make(chan tun.Event),
	}
}

func (f *fakeLinuxTunDevice) File() *os.File {
	return nil
}

func (f *fakeLinuxTunDevice) Read(_ [][]byte, _ []int, _ int) (int, error) {
	return 0, io.EOF
}

func (f *fakeLinuxTunDevice) Write(bufs [][]byte, _ int) (int, error) {
	return len(bufs), nil
}

func (f *fakeLinuxTunDevice) MTU() (int, error) {
	return f.mtu, nil
}

func (f *fakeLinuxTunDevice) Name() (string, error) {
	return f.name, nil
}

func (f *fakeLinuxTunDevice) Events() <-chan tun.Event {
	return f.events
}

func (f *fakeLinuxTunDevice) Close() error {
	if !f.closed {
		close(f.events)
	}
	f.closed = true
	return nil
}

func (f *fakeLinuxTunDevice) BatchSize() int {
	return 1
}

type roundTripFunc func(*http.Request) (*http.Response, error)

func (f roundTripFunc) RoundTrip(req *http.Request) (*http.Response, error) {
	return f(req)
}

func containsString(values []string, needle string) bool {
	for _, value := range values {
		if value == needle {
			return true
		}
	}
	return false
}
