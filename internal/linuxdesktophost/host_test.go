package linuxdesktophost

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestNewClientControlHostPublishesLinuxTunThroughDedicatedHost(t *testing.T) {
	t.Parallel()

	host := NewClientControlHost(nil)
	info := host.Info()
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	capability := info.PlatformTunnels[0]
	if capability.Mode != clientcontrol.PlatformTunnelModeLinuxTun {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", capability.Mode, clientcontrol.PlatformTunnelModeLinuxTun)
	}
	if capability.Available {
		t.Fatal("platform_tunnels[0].available = true, want false")
	}
	if capability.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform_tunnels[0].missing_prerequisite = %q, want %q",
			capability.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if !strings.Contains(strings.ToLower(capability.Message), "dedicated packaged linux desktop host boundary") {
		t.Fatalf("platform_tunnels[0].message = %q, want dedicated Linux host boundary detail", capability.Message)
	}
	if len(capability.ExecutionPlans) != 1 {
		t.Fatalf("platform_tunnels[0].execution_plans len = %d, want 1", len(capability.ExecutionPlans))
	}
	if capability.ExecutionPlans[0].Plan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		t.Fatalf(
			"platform_tunnels[0].execution_plans[0].host_adapter = %q, want %q",
			capability.ExecutionPlans[0].Plan.HostAdapter,
			clientcontrol.RuntimeHostAdapterLinuxTun,
		)
	}
}

func TestLinuxTunControllerReturnsTypedFailClosedStartupResult(t *testing.T) {
	t.Parallel()

	controller := newLinuxTunController(currentLinuxTunCapability(clientcontrol.BuildIdentity{Target: "linux/amd64"}), nil)
	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeLinuxTun,
	})
	if err != nil {
		t.Fatalf("Start() error = %v, want nil typed capability result", err)
	}
	if result.Ready {
		t.Fatalf("Start().Ready = true, want false: %+v", result)
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("Start().Stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageCapabilityCheck)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"Start().MissingPrerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if result.ExecutionPlan == nil {
		t.Fatal("Start().ExecutionPlan = nil, want documented plan")
	}
	if result.ExecutionPlan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		t.Fatalf("Start().ExecutionPlan.HostAdapter = %q, want linux_tun", result.ExecutionPlan.HostAdapter)
	}
}

func TestLinuxTunControllerPermissionDeniedReturnsTypedStartFailure(t *testing.T) {
	t.Parallel()

	helper := &fakeLinuxTunHelper{
		startErr: &linuxTunHelperError{
			stage:        clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			prerequisite: clientcontrol.PlatformTunnelPrerequisitePermission,
			message:      "pkexec authorization was denied",
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), helper)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed permission failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if startErr.Result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"typed failure prerequisite = %q, want %q",
			startErr.Result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	if helper.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0", helper.cleanupCalls)
	}
}

func TestLinuxTunControllerHelperStartFailureCleansUpPartialState(t *testing.T) {
	t.Parallel()

	helper := &fakeLinuxTunHelper{
		startErr: &linuxTunHelperError{
			stage:           clientcontrol.PlatformTunnelStartupStageHostBringup,
			prerequisite:    clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message:         "helper failed after creating tun state",
			cleanupRequired: true,
		},
	}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), helper)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed host failure")
	}
	if helper.cleanupCalls != 1 {
		t.Fatalf("cleanupCalls = %d, want 1", helper.cleanupCalls)
	}
}

func TestLinuxTunControllerPassesOnlyLeaseAndPolicyDirectivesToHelper(t *testing.T) {
	t.Parallel()

	helper := &fakeLinuxTunHelper{}
	controller := newLinuxTunController(supportedLinuxTunCapability(""), helper)
	controller.setWireGuardTurnLeaseProvider(fakeLinuxTunLeaseProvider)

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
		ResolutionID:        "resolution-1",
		UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("Start() error = %v, want nil reserved fail-closed result", err)
	}
	if result.Ready {
		t.Fatalf("Start().Ready = true, want false: %+v", result)
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("Start().Stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageRuntimeAttach)
	}
	if helper.cleanupCalls != 1 {
		t.Fatalf("cleanupCalls = %d, want 1 after reserved startup cleanup", helper.cleanupCalls)
	}
	if helper.startup.Lease.ResolutionID != "resolution-1" {
		t.Fatalf("Lease.ResolutionID = %q, want resolution-1", helper.startup.Lease.ResolutionID)
	}
	if helper.startup.PolicyDirectives.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf(
			"PolicyDirectives.UnderlayRoutePolicy = %q, want %q",
			helper.startup.PolicyDirectives.UnderlayRoutePolicy,
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		)
	}
	if len(helper.startup.PolicyDirectives.UnderlayExclusions) != 1 ||
		helper.startup.PolicyDirectives.UnderlayExclusions[0] != "203.0.113.10:3478" {
		t.Fatalf("PolicyDirectives.UnderlayExclusions = %#v, want TURN endpoint exclusion", helper.startup.PolicyDirectives.UnderlayExclusions)
	}
	if !helper.startup.PolicyDirectives.DNSBypassRequired {
		t.Fatal("PolicyDirectives.DNSBypassRequired = false, want true")
	}
}

type fakeLinuxTunHelper struct {
	startup      LinuxTunHelperStartup
	startErr     error
	cleanupErr   error
	cleanupCalls int
}

func (f *fakeLinuxTunHelper) Start(_ context.Context, startup LinuxTunHelperStartup) error {
	f.startup = startup
	return f.startErr
}

func (f *fakeLinuxTunHelper) Cleanup(context.Context) error {
	f.cleanupCalls++
	return f.cleanupErr
}

func fakeLinuxTunLeaseProvider(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.WireGuardTurnExecutionLease, error) {
	return &clientcontrol.WireGuardTurnExecutionLease{
		ResolutionID:        "resolution-1",
		TURNServerAddress:   "203.0.113.10:3478",
		PeerEndpointAddress: "raw-wg.example.test:56042",
		ClientPrivateKey:    "key",
		ClientAddresses:     []string{"10.10.0.2/32"},
		PeerPublicKey:       "peer",
		AllowedIPs:          []string{"0.0.0.0/0"},
	}, nil
}
