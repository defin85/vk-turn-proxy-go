package clientcontrol

import (
	"context"
	"errors"
	"fmt"
	"runtime"
	"slices"
	"strings"
)

type PlatformTunnelStartError struct {
	Result PlatformTunnelStartResult
}

func (e *PlatformTunnelStartError) Error() string {
	if e == nil {
		return ""
	}
	if strings.TrimSpace(e.Result.Message) != "" {
		return e.Result.Message
	}
	if strings.TrimSpace(string(e.Result.Stage)) != "" {
		return fmt.Sprintf("platform tunnel startup failed at stage %s", e.Result.Stage)
	}
	return fmt.Sprintf("platform tunnel startup failed for mode %s", e.Result.Mode)
}

func platformTunnelStartResultFromError(err error) (PlatformTunnelStartResult, bool) {
	var startErr *PlatformTunnelStartError
	if !errors.As(err, &startErr) || startErr == nil {
		return PlatformTunnelStartResult{}, false
	}
	return startErr.Result, true
}

func WithPlatformTunnelCapabilities(capabilities []PlatformTunnelCapability) Option {
	return func(cfg *hostConfig) {
		cfg.platformTunnels = clonePlatformTunnelCapabilities(capabilities)
		cfg.tunnelsConfigured = true
	}
}

func WithPlatformTunnelStarter(start func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error)) Option {
	return func(cfg *hostConfig) {
		cfg.startTunnel = start
	}
}

func WithPlatformTunnelResumer(resume func(context.Context, PlatformTunnelResumeRequest) (PlatformTunnelStartResult, error)) Option {
	return func(cfg *hostConfig) {
		cfg.resumeTunnel = resume
	}
}

func normalizePlatformTunnelCapabilities(capabilities []PlatformTunnelCapability, build BuildIdentity) ([]PlatformTunnelCapability, error) {
	snapshot := clonePlatformTunnelCapabilities(capabilities)
	if len(snapshot) == 0 {
		snapshot = defaultPlatformTunnelCapabilities(build)
	} else {
		for index := range snapshot {
			if len(snapshot[index].ExecutionPlans) == 0 {
				snapshot[index].ExecutionPlans = defaultRuntimeExecutionPlansForPlatformTunnel(snapshot[index])
			}
		}
	}
	if err := validatePlatformTunnelCapabilities(snapshot); err != nil {
		return defaultPlatformTunnelCapabilities(build), err
	}
	return snapshot, nil
}

func clonePlatformTunnelCapabilities(capabilities []PlatformTunnelCapability) []PlatformTunnelCapability {
	if len(capabilities) == 0 {
		return nil
	}
	out := make([]PlatformTunnelCapability, 0, len(capabilities))
	for _, capability := range capabilities {
		copyCapability := capability
		if len(capability.SatisfiedPrerequisites) > 0 {
			copyCapability.SatisfiedPrerequisites = append([]PlatformTunnelPrerequisite(nil), capability.SatisfiedPrerequisites...)
		}
		copyCapability.ExecutionPlans = cloneRuntimeExecutionPlanDescriptors(capability.ExecutionPlans)
		out = append(out, copyCapability)
	}
	return out
}

func defaultPlatformTunnelCapabilities(build BuildIdentity) []PlatformTunnelCapability {
	mode, ok := defaultPlatformTunnelMode(build)
	if !ok {
		capabilities := []PlatformTunnelCapability{{
			Mode:                PlatformTunnelModeLinuxTun,
			Available:           false,
			MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
			Message:             "This host does not publish a platform tunnel implementation for its current build target.",
		}}
		capabilities[0].ExecutionPlans = defaultRuntimeExecutionPlansForPlatformTunnel(capabilities[0])
		return capabilities
	}
	capabilities := []PlatformTunnelCapability{{
		Mode:                mode,
		Available:           false,
		MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
		Message:             fmt.Sprintf("The %s host does not yet implement platform tunnel startup for mode %s.", hostTargetLabel(build), mode),
	}}
	capabilities[0].ExecutionPlans = defaultRuntimeExecutionPlansForPlatformTunnel(capabilities[0])
	return capabilities
}

func defaultPlatformTunnelMode(build BuildIdentity) (PlatformTunnelMode, bool) {
	target := strings.ToLower(strings.TrimSpace(build.Target))
	switch {
	case strings.HasPrefix(target, "android/"):
		return PlatformTunnelModeAndroidVPNService, true
	case strings.HasPrefix(target, "ios/"), strings.HasPrefix(target, "darwin/"), strings.HasPrefix(target, "macos/"):
		return PlatformTunnelModeAppleNetworkExtension, true
	case strings.HasPrefix(target, "windows/"):
		return PlatformTunnelModeWindowsWintun, true
	case strings.HasPrefix(target, "linux/"):
		return PlatformTunnelModeLinuxTun, true
	}

	switch runtime.GOOS {
	case "android":
		return PlatformTunnelModeAndroidVPNService, true
	case "darwin":
		return PlatformTunnelModeAppleNetworkExtension, true
	case "windows":
		return PlatformTunnelModeWindowsWintun, true
	case "linux":
		return PlatformTunnelModeLinuxTun, true
	default:
		return "", false
	}
}

func validatePlatformTunnelCapabilities(capabilities []PlatformTunnelCapability) error {
	seenModes := make(map[PlatformTunnelMode]struct{}, len(capabilities))
	for _, capability := range capabilities {
		if err := validatePlatformTunnelCapability(capability); err != nil {
			return err
		}
		if _, exists := seenModes[capability.Mode]; exists {
			return fmt.Errorf("duplicate platform tunnel mode %s in capability report", capability.Mode)
		}
		seenModes[capability.Mode] = struct{}{}
	}
	return nil
}

func validatePlatformTunnelCapability(capability PlatformTunnelCapability) error {
	if !isKnownPlatformTunnelMode(capability.Mode) {
		return fmt.Errorf("unknown platform tunnel mode %q in capability report", capability.Mode)
	}
	seenPrerequisites := make(map[PlatformTunnelPrerequisite]struct{}, len(capability.SatisfiedPrerequisites))
	for _, prerequisite := range capability.SatisfiedPrerequisites {
		if !isKnownPlatformTunnelPrerequisite(prerequisite) {
			return fmt.Errorf("mode %s reports unknown satisfied prerequisite %q", capability.Mode, prerequisite)
		}
		if _, exists := seenPrerequisites[prerequisite]; exists {
			return fmt.Errorf("mode %s reports duplicate satisfied prerequisite %q", capability.Mode, prerequisite)
		}
		seenPrerequisites[prerequisite] = struct{}{}
	}
	if len(capability.ExecutionPlans) == 0 {
		capability.ExecutionPlans = defaultRuntimeExecutionPlansForPlatformTunnel(capability)
	}
	supportedDefaults := 0
	for _, plan := range capability.ExecutionPlans {
		if err := validateRuntimeExecutionPlanDescriptor(plan); err != nil {
			return fmt.Errorf("mode %s reports invalid execution plan: %w", capability.Mode, err)
		}
		if plan.Plan.HostAdapter != runtimeHostAdapterForPlatformTunnelMode(capability.Mode) {
			return fmt.Errorf("mode %s reports execution plan for mismatched host_adapter %q", capability.Mode, plan.Plan.HostAdapter)
		}
		if plan.SupportState == RuntimeExecutionPlanSupportStateSupported && !capability.Available {
			return fmt.Errorf("mode %s is unavailable but reports a supported execution plan", capability.Mode)
		}
		if plan.Default && plan.SupportState == RuntimeExecutionPlanSupportStateSupported {
			supportedDefaults++
		}
	}
	if supportedDefaults > 1 {
		return fmt.Errorf("mode %s reports multiple default supported execution plans", capability.Mode)
	}
	if capability.Available {
		if len(capability.SatisfiedPrerequisites) == 0 {
			return fmt.Errorf("mode %s is available but satisfied_prerequisites is empty", capability.Mode)
		}
		if strings.TrimSpace(string(capability.MissingPrerequisite)) != "" {
			return fmt.Errorf("mode %s is available but still reports missing prerequisite %q", capability.Mode, capability.MissingPrerequisite)
		}
		return nil
	}
	if !isKnownPlatformTunnelPrerequisite(capability.MissingPrerequisite) {
		return fmt.Errorf("mode %s is unavailable but missing_prerequisite is empty or invalid", capability.Mode)
	}
	return nil
}

func validatePlatformTunnelStartResult(req PlatformTunnelStartRequest, result PlatformTunnelStartResult) error {
	if !isKnownPlatformTunnelMode(result.Mode) {
		return fmt.Errorf("startup result reports unknown mode %q", result.Mode)
	}
	if result.Mode != req.Mode {
		return fmt.Errorf("startup result mode %s does not match requested mode %s", result.Mode, req.Mode)
	}
	if strings.TrimSpace(string(result.Stage)) != "" && !isKnownPlatformTunnelStartupStage(result.Stage) {
		return fmt.Errorf("startup result for mode %s reports unknown stage %q", result.Mode, result.Stage)
	}
	if strings.TrimSpace(string(result.MissingPrerequisite)) != "" && !isKnownPlatformTunnelPrerequisite(result.MissingPrerequisite) {
		return fmt.Errorf("startup result for mode %s reports unknown missing_prerequisite %q", result.Mode, result.MissingPrerequisite)
	}
	if result.ExecutionPlan != nil {
		if err := validateRuntimeExecutionPlan(*result.ExecutionPlan); err != nil {
			return fmt.Errorf("startup result for mode %s reports invalid execution_plan: %w", result.Mode, err)
		}
	}
	if strings.TrimSpace(result.StartupAttemptID) != "" {
		if result.Ready {
			return fmt.Errorf("startup result for mode %s is ready but still reports startup_attempt_id", result.Mode)
		}
		if result.Stage != PlatformTunnelStartupStagePermissionAcquire {
			return fmt.Errorf("startup result for mode %s reports startup_attempt_id outside permission_acquire", result.Mode)
		}
		if result.MissingPrerequisite != PlatformTunnelPrerequisitePermission {
			return fmt.Errorf("startup result for mode %s reports startup_attempt_id without permission prerequisite", result.Mode)
		}
	}
	if result.Ready {
		if strings.TrimSpace(string(result.MissingPrerequisite)) != "" {
			return fmt.Errorf("startup result for mode %s is ready but still reports missing_prerequisite %q", result.Mode, result.MissingPrerequisite)
		}
		return nil
	}
	if !isKnownPlatformTunnelStartupStage(result.Stage) {
		return fmt.Errorf("startup result for mode %s is not ready but missing stage", result.Mode)
	}
	if strings.TrimSpace(string(result.MissingPrerequisite)) == "" {
		return fmt.Errorf("startup result for mode %s is not ready but missing_prerequisite is empty", result.Mode)
	}
	return nil
}

func defaultPlatformTunnelStarter(capabilities []PlatformTunnelCapability) func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
	snapshot := clonePlatformTunnelCapabilities(capabilities)
	return func(_ context.Context, req PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
		for _, capability := range snapshot {
			if capability.Mode != req.Mode {
				continue
			}
			selectedPlan, err := selectPlatformTunnelExecutionPlanDescriptor(capability.ExecutionPlans, req.ExecutionPlan)
			if err != nil {
				return PlatformTunnelStartResult{
					Mode:                req.Mode,
					ExecutionPlan:       cloneRuntimeExecutionPlan(req.ExecutionPlan),
					Ready:               false,
					Stage:               PlatformTunnelStartupStageCapabilityCheck,
					MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
					Message:             err.Error(),
				}, nil
			}
			if selectedPlan.SupportState != RuntimeExecutionPlanSupportStateSupported || !capability.Available {
				return PlatformTunnelStartResult{
					Mode:                req.Mode,
					ExecutionPlan:       cloneRuntimeExecutionPlan(&selectedPlan.Plan),
					Ready:               false,
					Stage:               PlatformTunnelStartupStageCapabilityCheck,
					MissingPrerequisite: capability.MissingPrerequisite,
					Message:             firstNonEmpty(selectedPlan.Message, capability.Message),
				}, nil
			}
			return PlatformTunnelStartResult{
				Mode:                req.Mode,
				ExecutionPlan:       cloneRuntimeExecutionPlan(&selectedPlan.Plan),
				Ready:               false,
				Stage:               PlatformTunnelStartupStageHostBringup,
				MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
				Message:             fmt.Sprintf("Platform tunnel mode %s documents execution plan %s/%s/%s/%s but this host does not implement startup yet.", req.Mode, selectedPlan.Plan.AccessMethod, selectedPlan.Plan.CarrierFamily, selectedPlan.Plan.EngineFamily, selectedPlan.Plan.HostAdapter),
			}, nil
		}

		return PlatformTunnelStartResult{
			Mode:                req.Mode,
			ExecutionPlan:       cloneRuntimeExecutionPlan(req.ExecutionPlan),
			Ready:               false,
			Stage:               PlatformTunnelStartupStageCapabilityCheck,
			MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
			Message:             fmt.Sprintf("Platform tunnel mode %s is not reported by this host.", req.Mode),
		}, nil
	}
}

func isKnownPlatformTunnelMode(mode PlatformTunnelMode) bool {
	switch mode {
	case PlatformTunnelModeAndroidVPNService,
		PlatformTunnelModeAppleNetworkExtension,
		PlatformTunnelModeWindowsWintun,
		PlatformTunnelModeLinuxTun:
		return true
	default:
		return false
	}
}

func isKnownPlatformTunnelPrerequisite(prerequisite PlatformTunnelPrerequisite) bool {
	switch prerequisite {
	case PlatformTunnelPrerequisitePermission,
		PlatformTunnelPrerequisiteEntitlement,
		PlatformTunnelPrerequisitePrivilegedExtension,
		PlatformTunnelPrerequisiteDriver,
		PlatformTunnelPrerequisiteRouteExclusion,
		PlatformTunnelPrerequisiteDNSBypass,
		PlatformTunnelPrerequisiteAppRoutingPolicy,
		PlatformTunnelPrerequisiteHostImplementation:
		return true
	default:
		return false
	}
}

func isKnownPlatformTunnelApplicationRoutingPolicy(policy PlatformTunnelApplicationRoutingPolicy) bool {
	switch policy {
	case PlatformTunnelApplicationRoutingPolicyAllApps,
		PlatformTunnelApplicationRoutingPolicyAllowedPackages,
		PlatformTunnelApplicationRoutingPolicyDisallowedPackages:
		return true
	default:
		return false
	}
}

func isKnownPlatformTunnelStartupStage(stage PlatformTunnelStartupStage) bool {
	switch stage {
	case PlatformTunnelStartupStageCapabilityCheck,
		PlatformTunnelStartupStagePermissionAcquire,
		PlatformTunnelStartupStageEntitlementAcquire,
		PlatformTunnelStartupStageDriverCheck,
		PlatformTunnelStartupStageRouteValidate,
		PlatformTunnelStartupStageHostBringup,
		PlatformTunnelStartupStageRuntimeAttach:
		return true
	default:
		return false
	}
}

func hostTargetLabel(build BuildIdentity) string {
	if target := strings.TrimSpace(build.Target); target != "" {
		return target
	}
	return runtime.GOOS
}

func normalizePlatformTunnelStartRequest(req PlatformTunnelStartRequest) (PlatformTunnelStartRequest, error) {
	if req.Mode != PlatformTunnelModeAndroidVPNService {
		if strings.TrimSpace(string(req.ApplicationRoutingPolicy)) != "" || len(req.AllowedPackages) > 0 || len(req.DisallowedPackages) > 0 {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: mode %s does not accept application routing policy", ErrPlatformTunnelAppRoutingPolicyInvalid, req.Mode)
		}
		return req, nil
	}

	normalized := req
	if strings.TrimSpace(string(normalized.ApplicationRoutingPolicy)) == "" {
		normalized.ApplicationRoutingPolicy = PlatformTunnelApplicationRoutingPolicyAllApps
	}
	if !isKnownPlatformTunnelApplicationRoutingPolicy(normalized.ApplicationRoutingPolicy) {
		return PlatformTunnelStartRequest{}, fmt.Errorf("%w: unknown application_routing_policy %q", ErrPlatformTunnelAppRoutingPolicyInvalid, normalized.ApplicationRoutingPolicy)
	}
	normalized.AllowedPackages = normalizePackageNames(normalized.AllowedPackages)
	normalized.DisallowedPackages = normalizePackageNames(normalized.DisallowedPackages)
	if len(normalized.AllowedPackages) > 0 && len(normalized.DisallowedPackages) > 0 {
		return PlatformTunnelStartRequest{}, fmt.Errorf("%w: mixed allowed_packages and disallowed_packages are not supported", ErrPlatformTunnelAppRoutingPolicyInvalid)
	}
	switch normalized.ApplicationRoutingPolicy {
	case PlatformTunnelApplicationRoutingPolicyAllApps:
		if len(normalized.AllowedPackages) > 0 || len(normalized.DisallowedPackages) > 0 {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: all_apps cannot include package lists", ErrPlatformTunnelAppRoutingPolicyInvalid)
		}
	case PlatformTunnelApplicationRoutingPolicyAllowedPackages:
		if len(normalized.AllowedPackages) == 0 || len(normalized.DisallowedPackages) > 0 {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: allowed_packages requires a non-empty allowed_packages list", ErrPlatformTunnelAppRoutingPolicyInvalid)
		}
	case PlatformTunnelApplicationRoutingPolicyDisallowedPackages:
		if len(normalized.DisallowedPackages) == 0 || len(normalized.AllowedPackages) > 0 {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: disallowed_packages requires a non-empty disallowed_packages list", ErrPlatformTunnelAppRoutingPolicyInvalid)
		}
	}
	return normalized, nil
}

func normalizePlatformTunnelResumeRequest(req PlatformTunnelResumeRequest) (PlatformTunnelResumeRequest, error) {
	normalized := req
	normalized.StartupAttemptID = strings.TrimSpace(normalized.StartupAttemptID)
	if normalized.StartupAttemptID == "" {
		return PlatformTunnelResumeRequest{}, ErrPlatformTunnelStartupAttemptRequired
	}
	return normalized, nil
}

func normalizePackageNames(packages []string) []string {
	if len(packages) == 0 {
		return nil
	}
	out := make([]string, 0, len(packages))
	for _, pkg := range packages {
		pkg = strings.TrimSpace(pkg)
		if pkg == "" {
			continue
		}
		if slices.Contains(out, pkg) {
			continue
		}
		out = append(out, pkg)
	}
	return out
}
