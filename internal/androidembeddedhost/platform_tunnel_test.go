package androidembeddedhost

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestManagerReportsSupportedAndroidVPNServiceCapabilityFromController(t *testing.T) {
	t.Parallel()

	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability("packaged Android host owns android_vpn_service startup"),
		&fakeAndroidVPNServiceLifecycle{},
	)))
	baseURL := ensureStartedManager(t, manager)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(baseURL + "/v1/host")
	if err != nil {
		t.Fatalf("GET /v1/host error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /v1/host status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var info clientcontrol.HostInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		t.Fatalf("decode host info: %v", err)
	}
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	capability := info.PlatformTunnels[0]
	if capability.Mode != clientcontrol.PlatformTunnelModeAndroidVPNService {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", capability.Mode, clientcontrol.PlatformTunnelModeAndroidVPNService)
	}
	if capability.Available {
		t.Fatal("platform_tunnels[0].available = true, want false until strict carrier/materializer exists")
	}
	if capability.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform_tunnels[0].missing_prerequisite = %q, want %q",
			capability.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if len(capability.ExecutionPlans) != 1 {
		t.Fatalf("platform_tunnels[0].execution_plans len = %d, want 1", len(capability.ExecutionPlans))
	}
	if capability.ExecutionPlans[0].SupportState != clientcontrol.RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf(
			"platform_tunnels[0].execution_plans[0].support_state = %q, want %q",
			capability.ExecutionPlans[0].SupportState,
			clientcontrol.RuntimeExecutionPlanSupportStateUnavailable,
		)
	}
	if capability.ExecutionPlans[0].Plan.HostAdapter != clientcontrol.RuntimeHostAdapterAndroidVPNService {
		t.Fatalf(
			"platform_tunnels[0].execution_plans[0].plan.host_adapter = %q, want %q",
			capability.ExecutionPlans[0].Plan.HostAdapter,
			clientcontrol.RuntimeHostAdapterAndroidVPNService,
		)
	}
	if len(capability.SupportedUnderlayRoutePolicies) != 2 {
		t.Fatalf("platform_tunnels[0].supported_underlay_route_policies len = %d, want 2", len(capability.SupportedUnderlayRoutePolicies))
	}
	if capability.SupportedUnderlayRoutePolicies[0] != clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard {
		t.Fatalf(
			"platform_tunnels[0].supported_underlay_route_policies[0] = %q, want %q",
			capability.SupportedUnderlayRoutePolicies[0],
			clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard,
		)
	}
	if capability.SupportedUnderlayRoutePolicies[1] != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf(
			"platform_tunnels[0].supported_underlay_route_policies[1] = %q, want %q",
			capability.SupportedUnderlayRoutePolicies[1],
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		)
	}
}

func TestManagerPlatformTunnelStartPermissionAcquireFailureStaysFailClosed(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		acquirePermissionErr: errors.New("operator denied Android VpnService permission"),
	}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanup calls = %d, want 0", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission" {
		t.Fatalf("lifecycle calls = %q, want %q", got, "acquire_permission")
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestManagerPlatformTunnelStartReturnsResumablePermissionAttempt(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		acquirePermissionErr: newAndroidPermissionPendingError("android vpn permission prompt launched"),
	}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	if strings.TrimSpace(result.StartupAttemptID) == "" {
		t.Fatal("platform tunnel start startup_attempt_id = empty, want resumable attempt id")
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanup calls = %d, want 0", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission" {
		t.Fatalf("lifecycle calls = %q, want %q", got, "acquire_permission")
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestManagerPlatformTunnelResumeContinuesAfterPermissionGrantAndFailsWithoutMaterializedRuntime(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		acquirePermissionErr: newAndroidPermissionPendingError("android vpn permission prompt launched"),
	}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)

	startResult := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if strings.TrimSpace(startResult.StartupAttemptID) == "" {
		t.Fatal("startup attempt id = empty, want resumable attempt")
	}

	resumeResult := resumePlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelResumeRequest{
		StartupAttemptID: startResult.StartupAttemptID,
	})
	if resumeResult.Ready {
		t.Fatalf("platform tunnel resume result ready = true, want false: %+v", resumeResult)
	}
	if resumeResult.Stage != clientcontrol.PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("platform tunnel resume stage = %q, want %q", resumeResult.Stage, clientcontrol.PlatformTunnelStartupStageRuntimeAttach)
	}
	if resumeResult.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform tunnel resume missing_prerequisite = %q, want %q",
			resumeResult.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if !strings.Contains(strings.ToLower(resumeResult.Message), "resolution") {
		t.Fatalf("platform tunnel resume message = %q, want resolution-related failure", resumeResult.Message)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,resume_after_permission,validate_route_policy,cleanup" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,resume_after_permission,validate_route_policy,cleanup",
		)
	}
	assertAndroidVPNExecutionPlan(t, resumeResult.ExecutionPlan)
}

func TestManagerPlatformTunnelStartRouteValidationFailureCleansUp(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name                 string
		err                  error
		wantPrerequisite     clientcontrol.PlatformTunnelPrerequisite
		wantMessageSubstring string
	}{
		{
			name:                 "route exclusion",
			err:                  newAndroidRouteExclusionError("control-plane route exclusion is unsafe"),
			wantPrerequisite:     clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			wantMessageSubstring: "route exclusion",
		},
		{
			name:                 "dns bypass",
			err:                  newAndroidDNSBypassError("provider DNS bypass cannot be applied safely"),
			wantPrerequisite:     clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			wantMessageSubstring: "DNS bypass",
		},
		{
			name:                 "app routing policy",
			err:                  newAndroidAppRoutingPolicyError("requested package allowlist is invalid"),
			wantPrerequisite:     clientcontrol.PlatformTunnelPrerequisiteAppRoutingPolicy,
			wantMessageSubstring: "allowlist",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			lifecycle := &fakeAndroidVPNServiceLifecycle{
				validateRouteErr: tc.err,
			}
			manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
				supportedAndroidVPNServiceCapability(""),
				lifecycle,
			)))
			baseURL := ensureStartedManager(t, manager)

			result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
				Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
			})

			if result.Ready {
				t.Fatal("platform tunnel start result ready = true, want false")
			}
			if result.Stage != clientcontrol.PlatformTunnelStartupStageRouteValidate {
				t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageRouteValidate)
			}
			if result.MissingPrerequisite != tc.wantPrerequisite {
				t.Fatalf("platform tunnel start missing_prerequisite = %q, want %q", result.MissingPrerequisite, tc.wantPrerequisite)
			}
			if !strings.Contains(strings.ToLower(result.Message), strings.ToLower(tc.wantMessageSubstring)) {
				t.Fatalf("platform tunnel start message = %q, want substring %q", result.Message, tc.wantMessageSubstring)
			}
			if lifecycle.cleanupCalls != 1 {
				t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
			}
			if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,cleanup" {
				t.Fatalf(
					"lifecycle calls = %q, want %q",
					got,
					"acquire_permission,validate_route_policy,cleanup",
				)
			}
			assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
		})
	}
}

func TestManagerPlatformTunnelStartRejectsUnsupportedUnderlayRoutePolicyBeforePermissionPrompt(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		clientcontrol.PlatformTunnelCapability{
			Mode:      clientcontrol.PlatformTunnelModeAndroidVPNService,
			Available: true,
			SatisfiedPrerequisites: []clientcontrol.PlatformTunnelPrerequisite{
				clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
				clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			},
			SupportedUnderlayRoutePolicies: []clientcontrol.PlatformTunnelUnderlayRoutePolicy{
				clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard,
			},
			ExecutionPlans: androidVPNServiceExecutionPlans(true, ""),
		},
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode:                clientcontrol.PlatformTunnelModeAndroidVPNService,
		UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageCapabilityCheck)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteRouteExclusion {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
		)
	}
	if result.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf(
			"platform tunnel start underlay_route_policy = %q, want %q",
			result.UnderlayRoutePolicy,
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		)
	}
	if len(lifecycle.calls) != 0 {
		t.Fatalf("lifecycle calls = %+v, want none before permission acquire", lifecycle.calls)
	}
}

func TestManagerPlatformTunnelStartHostBringupFailureCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		bringupErr: errors.New("android VpnService interface setup failed"),
	}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	controller.setWireGuardTurnLeaseProvider(testWireGuardTurnLeaseProvider())
	manager := New(WithHostFactory(testHostFactory(controller, nil)))
	baseURL := ensureStartedManager(t, manager)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageHostBringup {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageHostBringup)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if lifecycle.cleanupCalls != 1 {
		t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,bringup_host,cleanup" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,validate_route_policy,bringup_host,cleanup",
		)
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestManagerPlatformTunnelStartRuntimeAttachFailureCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		attachErr: errors.New("android shared runtime attach failed"),
	}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	controller.setWireGuardTurnLeaseProvider(testWireGuardTurnLeaseProvider())
	manager := New(WithHostFactory(testHostFactory(controller, nil)))
	baseURL := ensureStartedManager(t, manager)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageRuntimeAttach)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if !strings.Contains(strings.ToLower(result.Message), "runtime attach") {
		t.Fatalf("platform tunnel start message = %q, want runtime-attach-related failure", result.Message)
	}
	if lifecycle.cleanupCalls != 1 {
		t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,bringup_host,attach_runtime,cleanup" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,validate_route_policy,bringup_host,attach_runtime,cleanup",
		)
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestManagerPlatformTunnelStopCleansUpActiveAndroidVPNService(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)

	result := stopPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStopRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})

	if result.Mode != clientcontrol.PlatformTunnelModeAndroidVPNService {
		t.Fatalf("platform tunnel stop mode = %q, want %q", result.Mode, clientcontrol.PlatformTunnelModeAndroidVPNService)
	}
	if !result.Stopped {
		t.Fatal("platform tunnel stop stopped = false, want true")
	}
	if lifecycle.cleanupCalls != 1 {
		t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "cleanup" {
		t.Fatalf("lifecycle calls = %q, want %q", got, "cleanup")
	}
}

func TestAndroidVPNServiceControllerPassesMaterializedLeaseToRuntimeAttach(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	controller.setWireGuardTurnLeaseProvider(testWireGuardTurnLeaseProvider())

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("controller.Start() error = %v", err)
	}
	if !result.Ready {
		t.Fatalf("controller.Start() ready = false, want true: %+v", result)
	}
	if result.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard {
		t.Fatalf("controller.Start() underlay_route_policy = %q, want %q", result.UnderlayRoutePolicy, clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,bringup_host,attach_runtime" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,validate_route_policy,bringup_host,attach_runtime",
		)
	}
	if len(lifecycle.attachedLeasePresence) != 1 || !lifecycle.attachedLeasePresence[0] {
		t.Fatalf("attached lease presence = %+v, want [true]", lifecycle.attachedLeasePresence)
	}
	if len(lifecycle.attachedLeaseIDs) != 1 || lifecycle.attachedLeaseIDs[0] != "resolution-android-1" {
		t.Fatalf("attached lease ids = %+v, want [resolution-android-1]", lifecycle.attachedLeaseIDs)
	}
}

type fakeAndroidVPNServiceLifecycle struct {
	acquirePermissionErr error
	resumePermissionErr  error
	validateRouteErr     error
	bringupErr           error
	attachErr            error
	cleanupErr           error

	calls                 []string
	cleanupCalls          int
	attachedLeaseIDs      []string
	attachedLeasePresence []bool
}

func (f *fakeAndroidVPNServiceLifecycle) AcquirePermission(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "acquire_permission")
	return f.acquirePermissionErr
}

func (f *fakeAndroidVPNServiceLifecycle) ResumeAfterPermission(_ context.Context, _ string, _ clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "resume_after_permission")
	return f.resumePermissionErr
}

func (f *fakeAndroidVPNServiceLifecycle) ValidateRoutePolicy(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "validate_route_policy")
	return f.validateRouteErr
}

func (f *fakeAndroidVPNServiceLifecycle) BringupHost(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest, _ *clientcontrol.RuntimeExecutionPlan, _ *clientcontrol.WireGuardTurnExecutionLease) error {
	f.calls = append(f.calls, "bringup_host")
	return f.bringupErr
}

func (f *fakeAndroidVPNServiceLifecycle) AttachRuntime(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest, _ *clientcontrol.RuntimeExecutionPlan, lease *clientcontrol.WireGuardTurnExecutionLease) error {
	f.calls = append(f.calls, "attach_runtime")
	f.attachedLeasePresence = append(f.attachedLeasePresence, lease != nil)
	if lease != nil {
		f.attachedLeaseIDs = append(f.attachedLeaseIDs, lease.ResolutionID)
	} else {
		f.attachedLeaseIDs = append(f.attachedLeaseIDs, "")
	}
	return f.attachErr
}

func (f *fakeAndroidVPNServiceLifecycle) Cleanup(_ context.Context) error {
	f.calls = append(f.calls, "cleanup")
	f.cleanupCalls++
	return f.cleanupErr
}

func testWireGuardTurnLeaseProvider() androidVPNServiceLeaseProvider {
	return func(
		_ context.Context,
		req clientcontrol.PlatformTunnelStartRequest,
		plan *clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		return &clientcontrol.WireGuardTurnExecutionLease{
			ResolutionID:         req.ResolutionID,
			AccessMethod:         plan.AccessMethod,
			CarrierFamily:        plan.CarrierFamily,
			EngineFamily:         plan.EngineFamily,
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   clientcontrol.WireGuardTurnRemoteEndpointRoleDatagramTermination,
			TURNServerAddress:    "turn.example.test:3478",
			TURNUsername:         "turn-user",
			TURNPassword:         "turn-pass",
			PeerEndpointAddress:  "176.109.104.105:51871",
			ClientPrivateKey:     "privkey-test-123",
			ClientAddresses:      []string{"10.99.0.2/32"},
			PeerPublicKey:        "peerpub-test-123",
			AllowedIPs:           []string{"0.0.0.0/0"},
		}, nil
	}
}

func testHostFactory(
	controller platformTunnelController,
	materializer clientcontrol.WireGuardTurnMaterializer,
) func(*slog.Logger) *clientcontrol.Host {
	return func(logger *slog.Logger) *clientcontrol.Host {
		opts := []clientcontrol.Option{
			clientcontrol.WithLogger(logger),
			clientcontrol.WithBuildIdentity(currentBuildIdentity()),
			clientcontrol.WithRegistry(mobileProviderRegistry()),
			clientcontrol.WithInteractiveChallengeMetadataResolver(mobileChallengeMetadata),
		}
		if materializer != nil {
			opts = append(opts, clientcontrol.WithWireGuardTurnMaterializer(materializer))
		}
		if controller != nil {
			opts = append(opts,
				clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{
					controller.Capability(),
				}),
				clientcontrol.WithPlatformTunnelStarter(controller.Start),
				clientcontrol.WithPlatformTunnelResumer(controller.Resume),
				clientcontrol.WithPlatformTunnelStopper(controller.Stop),
			)
		}
		return clientcontrol.New(opts...)
	}
}

func ensureStartedManager(t *testing.T, manager *Manager) string {
	t.Helper()

	baseURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("EnsureStarted() error = %v", err)
	}
	t.Cleanup(func() {
		if err := manager.Stop(); err != nil {
			t.Fatalf("Stop() error = %v", err)
		}
	})
	return baseURL
}

func startPlatformTunnel(
	t *testing.T,
	baseURL string,
	req clientcontrol.PlatformTunnelStartRequest,
) clientcontrol.PlatformTunnelStartResult {
	t.Helper()

	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/platform-tunnels/start", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/platform-tunnels/start error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/start status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var result clientcontrol.PlatformTunnelStartResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode platform tunnel start result: %v", err)
	}
	return result
}

func resumePlatformTunnel(
	t *testing.T,
	baseURL string,
	req clientcontrol.PlatformTunnelResumeRequest,
) clientcontrol.PlatformTunnelStartResult {
	t.Helper()

	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/platform-tunnels/resume", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/platform-tunnels/resume error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/resume status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var result clientcontrol.PlatformTunnelStartResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode platform tunnel resume result: %v", err)
	}
	return result
}

func stopPlatformTunnel(
	t *testing.T,
	baseURL string,
	req clientcontrol.PlatformTunnelStopRequest,
) clientcontrol.PlatformTunnelStopResult {
	t.Helper()

	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/platform-tunnels/stop", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/platform-tunnels/stop error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/stop status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var result clientcontrol.PlatformTunnelStopResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode platform tunnel stop result: %v", err)
	}
	return result
}

func assertAndroidVPNExecutionPlan(t *testing.T, plan *clientcontrol.RuntimeExecutionPlan) {
	t.Helper()

	if plan == nil {
		t.Fatal("execution plan = nil, want android_vpn_service plan")
	}
	if plan.EngineFamily != clientcontrol.RuntimeEngineFamilyWireGuardNative {
		t.Fatalf("execution plan engine_family = %q, want %q", plan.EngineFamily, clientcontrol.RuntimeEngineFamilyWireGuardNative)
	}
	if plan.HostAdapter != clientcontrol.RuntimeHostAdapterAndroidVPNService {
		t.Fatalf("execution plan host_adapter = %q, want %q", plan.HostAdapter, clientcontrol.RuntimeHostAdapterAndroidVPNService)
	}
}
