package windowsdesktophost

import (
	"context"
	"errors"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestWindowsWintunControllerDefaultsUnderlayPolicyAndPublishesExclusions(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeWindowsWintunLifecycle{
		routeState: &windowsRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"1.1.1.1", "203.0.113.10"},
		},
	}
	controller := newWindowsWintunController(supportedWindowsWintunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(func(
		context.Context,
		clientcontrol.PlatformTunnelStartRequest,
		*clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		return &clientcontrol.WireGuardTurnExecutionLease{
			ResolutionID:         "resolution-1",
			AccessMethod:         clientcontrol.RuntimeAccessMethodTURNCredentials,
			CarrierFamily:        clientcontrol.RuntimeCarrierFamilyTURNDatagram,
			EngineFamily:         clientcontrol.RuntimeEngineFamilyWireGuardNative,
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   clientcontrol.WireGuardTurnRemoteEndpointRoleDatagramTermination,
			TURNServerAddress:    "203.0.113.10:3478",
			TURNUsername:         "user",
			TURNPassword:         "pass",
			PeerEndpointAddress:  "relay.example.test:3478",
			ClientPrivateKey:     "key",
			ClientAddresses:      []string{"10.10.0.2/32"},
			PeerPublicKey:        "peer",
			AllowedIPs:           []string{"0.0.0.0/0"},
		}, nil
	})

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeWindowsWintun,
		ResolutionID: "resolution-1",
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
	if result.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf(
			"Start().UnderlayRoutePolicy = %q, want %q",
			result.UnderlayRoutePolicy,
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		)
	}
	if len(result.UnderlayRouteExclusions) != 2 {
		t.Fatalf("Start().UnderlayRouteExclusions len = %d, want 2", len(result.UnderlayRouteExclusions))
	}
	if strings.Join(lifecycle.calls, ",") != "driver_check,route_validate,host_bringup,runtime_attach" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			strings.Join(lifecycle.calls, ","),
			"driver_check,route_validate,host_bringup,runtime_attach",
		)
	}
}

func TestWindowsWintunControllerCapabilityCheckFailureStaysFailClosed(t *testing.T) {
	t.Parallel()

	tests := []struct {
		name                string
		message             string
		missingPrerequisite clientcontrol.PlatformTunnelPrerequisite
	}{
		{
			name:                "missing packaged driver",
			message:             "The windows/amd64 host is missing the packaged Wintun DLL required for mode windows_wintun: stat wintun.dll: file does not exist",
			missingPrerequisite: clientcontrol.PlatformTunnelPrerequisiteDriver,
		},
		{
			name:                "missing elevated privilege",
			message:             "windows_wintun requires an elevated desktop host",
			missingPrerequisite: clientcontrol.PlatformTunnelPrerequisiteDriver,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			capability := supportedWindowsWintunCapability(tt.message)
			capability.Available = false
			capability.SatisfiedPrerequisites = nil
			capability.MissingPrerequisite = tt.missingPrerequisite
			for index := range capability.ExecutionPlans {
				capability.ExecutionPlans[index].SupportState = clientcontrol.RuntimeExecutionPlanSupportStateUnavailable
				capability.ExecutionPlans[index].Message = tt.message
			}

			controller := newWindowsWintunController(capability, nil)
			result, err := controller.Start(
				context.Background(),
				clientcontrol.PlatformTunnelStartRequest{
					Mode: clientcontrol.PlatformTunnelModeWindowsWintun,
				},
			)
			if err != nil {
				t.Fatalf("Start() error = %v, want nil typed capability_check result", err)
			}
			if result.Ready {
				t.Fatalf("Start().Ready = true, want false: %+v", result)
			}
			if result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
				t.Fatalf(
					"Start().Stage = %q, want %q",
					result.Stage,
					clientcontrol.PlatformTunnelStartupStageCapabilityCheck,
				)
			}
			if result.MissingPrerequisite != tt.missingPrerequisite {
				t.Fatalf(
					"Start().MissingPrerequisite = %q, want %q",
					result.MissingPrerequisite,
					tt.missingPrerequisite,
				)
			}
			if !strings.Contains(result.Message, tt.message) {
				t.Fatalf("Start().Message = %q, want substring %q", result.Message, tt.message)
			}
		})
	}
}

func TestMaterializerUnavailableWindowsWintunCapabilityStaysFailClosed(t *testing.T) {
	t.Parallel()

	capability := materializerUnavailableWindowsWintunCapability(
		clientcontrol.BuildIdentity{Target: "windows/amd64"},
		errors.New(`Windows WireGuard profile C:\Users\codex\.local\state\vk-turn-proxy-go\wg\desktop1-windows.conf does not exist`),
	)
	if capability.Available {
		t.Fatal("capability.Available = true, want false")
	}
	if capability.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"capability.MissingPrerequisite = %q, want %q",
			capability.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}

	controller := newWindowsWintunController(capability, nil)
	result, err := controller.Start(
		context.Background(),
		clientcontrol.PlatformTunnelStartRequest{
			Mode: clientcontrol.PlatformTunnelModeWindowsWintun,
		},
	)
	if err != nil {
		t.Fatalf("Start() error = %v, want nil typed capability_check result", err)
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
	if !strings.Contains(strings.ToLower(result.Message), "wireguard profile") {
		t.Fatalf("Start().Message = %q, want WireGuard profile detail", result.Message)
	}
}

func TestWindowsWintunControllerDriverFailureStopsBeforeCleanup(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeWindowsWintunLifecycle{
		driverErr: errors.New("Wintun driver is unavailable"),
	}
	controller := newWindowsWintunController(supportedWindowsWintunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeWindowsWintun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed driver_check failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageDriverCheck {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStageDriverCheck)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0", lifecycle.cleanupCalls)
	}
}

func TestWindowsWintunControllerRouteValidationFailureCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeWindowsWintunLifecycle{
		routeErr: &windowsWintunRoutePolicyError{
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			message:      "physical DNS server bypass is unavailable",
		},
	}
	controller := newWindowsWintunController(supportedWindowsWintunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeWindowsWintun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed route_validate failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageRouteValidate {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStageRouteValidate)
	}
	if startErr.Result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteDNSBypass {
		t.Fatalf(
			"typed failure missing_prerequisite = %q, want %q",
			startErr.Result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
		)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0 before host-owned stop cleanup", lifecycle.cleanupCalls)
	}
}

func TestWindowsWintunControllerRuntimeAttachFailureCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeWindowsWintunLifecycle{
		routeState: &windowsRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"203.0.113.10"},
		},
		attachErr: errors.New("runtime attach failed after partial Wintun bring-up"),
	}
	controller := newWindowsWintunController(supportedWindowsWintunCapability(""), lifecycle)
	controller.setWireGuardTurnLeaseProvider(fakeLeaseProvider)

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeWindowsWintun,
		ResolutionID: "resolution-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err == nil {
		t.Fatal("Start() error = nil, want typed runtime_attach failure")
	}
	startErr := new(clientcontrol.PlatformTunnelStartError)
	if !errors.As(err, &startErr) {
		t.Fatalf("Start() error = %v, want PlatformTunnelStartError", err)
	}
	if startErr.Result.Stage != clientcontrol.PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("typed failure stage = %q, want %q", startErr.Result.Stage, clientcontrol.PlatformTunnelStartupStageRuntimeAttach)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanupCalls = %d, want 0 before host-owned stop cleanup", lifecycle.cleanupCalls)
	}
}

type fakeWindowsWintunLifecycle struct {
	driverErr  error
	routeErr   error
	routeState *windowsRoutePolicyState
	bringupErr error
	attachErr  error

	calls        []string
	cleanupCalls int
}

func (f *fakeWindowsWintunLifecycle) CheckDriver(context.Context, clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "driver_check")
	return f.driverErr
}

func (f *fakeWindowsWintunLifecycle) ValidateRoutePolicy(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
	*clientcontrol.WireGuardTurnExecutionLease,
) (*windowsRoutePolicyState, error) {
	f.calls = append(f.calls, "route_validate")
	if f.routeErr != nil {
		return nil, f.routeErr
	}
	if f.routeState == nil {
		f.routeState = &windowsRoutePolicyState{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			Exclusions:          []string{"203.0.113.10"},
		}
	}
	return f.routeState, nil
}

func (f *fakeWindowsWintunLifecycle) BringupHost(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
	*clientcontrol.WireGuardTurnExecutionLease,
	*windowsRoutePolicyState,
) error {
	f.calls = append(f.calls, "host_bringup")
	return f.bringupErr
}

func (f *fakeWindowsWintunLifecycle) AttachRuntime(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
	*clientcontrol.WireGuardTurnExecutionLease,
	*windowsRoutePolicyState,
) error {
	f.calls = append(f.calls, "runtime_attach")
	return f.attachErr
}

func (f *fakeWindowsWintunLifecycle) Cleanup(context.Context) error {
	f.cleanupCalls++
	f.calls = append(f.calls, "cleanup")
	return nil
}

func fakeLeaseProvider(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.WireGuardTurnExecutionLease, error) {
	return &clientcontrol.WireGuardTurnExecutionLease{
		ResolutionID:         "resolution-1",
		AccessMethod:         clientcontrol.RuntimeAccessMethodTURNCredentials,
		CarrierFamily:        clientcontrol.RuntimeCarrierFamilyTURNDatagram,
		EngineFamily:         clientcontrol.RuntimeEngineFamilyWireGuardNative,
		RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   clientcontrol.WireGuardTurnRemoteEndpointRoleDatagramTermination,
		TURNServerAddress:    "203.0.113.10:3478",
		TURNUsername:         "user",
		TURNPassword:         "pass",
		PeerEndpointAddress:  "relay.example.test:3478",
		ClientPrivateKey:     "key",
		ClientAddresses:      []string{"10.10.0.2/32"},
		PeerPublicKey:        "peer",
		AllowedIPs:           []string{"0.0.0.0/0"},
	}, nil
}
