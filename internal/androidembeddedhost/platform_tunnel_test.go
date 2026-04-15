package androidembeddedhost

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
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

func TestManagerPlatformTunnelResumeContinuesAfterPermissionGrant(t *testing.T) {
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
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})
	if strings.TrimSpace(startResult.StartupAttemptID) == "" {
		t.Fatal("startup attempt id = empty, want resumable attempt")
	}

	resumeResult := resumePlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelResumeRequest{
		StartupAttemptID: startResult.StartupAttemptID,
	})
	if !resumeResult.Ready {
		t.Fatalf("platform tunnel resume result ready = false, want true: %+v", resumeResult)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,resume_after_permission,validate_route_policy,bringup_host,attach_runtime" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,resume_after_permission,validate_route_policy,bringup_host,attach_runtime",
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

func TestManagerPlatformTunnelStartHostBringupFailureCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		bringupErr: errors.New("android VpnService interface setup failed"),
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
		attachErr: errors.New("shared runtime could not attach to Android VpnService"),
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

type fakeAndroidVPNServiceLifecycle struct {
	acquirePermissionErr error
	resumePermissionErr  error
	validateRouteErr     error
	bringupErr           error
	attachErr            error
	cleanupErr           error

	calls        []string
	cleanupCalls int
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

func (f *fakeAndroidVPNServiceLifecycle) BringupHost(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "bringup_host")
	return f.bringupErr
}

func (f *fakeAndroidVPNServiceLifecycle) AttachRuntime(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest, _ *clientcontrol.RuntimeExecutionPlan) error {
	f.calls = append(f.calls, "attach_runtime")
	return f.attachErr
}

func (f *fakeAndroidVPNServiceLifecycle) Cleanup(_ context.Context) error {
	f.calls = append(f.calls, "cleanup")
	f.cleanupCalls++
	return f.cleanupErr
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
