package clientcontrol

import (
	"context"
	"errors"
	"fmt"
	"runtime"
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

func normalizePlatformTunnelCapabilities(capabilities []PlatformTunnelCapability, build BuildIdentity) ([]PlatformTunnelCapability, error) {
	snapshot := clonePlatformTunnelCapabilities(capabilities)
	if len(snapshot) == 0 {
		return defaultPlatformTunnelCapabilities(build), nil
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
		out = append(out, copyCapability)
	}
	return out
}

func defaultPlatformTunnelCapabilities(build BuildIdentity) []PlatformTunnelCapability {
	mode, ok := defaultPlatformTunnelMode(build)
	if !ok {
		return []PlatformTunnelCapability{{
			Mode:                PlatformTunnelModeLinuxTun,
			Available:           false,
			MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
			Message:             "This host does not publish a platform tunnel implementation for its current build target.",
		}}
	}
	return []PlatformTunnelCapability{{
		Mode:                mode,
		Available:           false,
		MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
		Message:             fmt.Sprintf("The %s host does not yet implement platform tunnel startup for mode %s.", hostTargetLabel(build), mode),
	}}
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
			if !capability.Available {
				return PlatformTunnelStartResult{
					Mode:                req.Mode,
					Ready:               false,
					Stage:               PlatformTunnelStartupStageCapabilityCheck,
					MissingPrerequisite: capability.MissingPrerequisite,
					Message:             capability.Message,
				}, nil
			}
			return PlatformTunnelStartResult{
				Mode:                req.Mode,
				Ready:               false,
				Stage:               PlatformTunnelStartupStageHostBringup,
				MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
				Message:             fmt.Sprintf("Platform tunnel mode %s is declared but this host does not implement startup yet.", req.Mode),
			}, nil
		}

		return PlatformTunnelStartResult{
			Mode:                req.Mode,
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
		PlatformTunnelPrerequisiteHostImplementation:
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
