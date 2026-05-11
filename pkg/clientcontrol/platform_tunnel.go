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

func WithPlatformTunnelStopper(stop func(context.Context, PlatformTunnelStopRequest) (PlatformTunnelStopResult, error)) Option {
	return func(cfg *hostConfig) {
		cfg.stopTunnel = stop
	}
}

func normalizePlatformTunnelCapabilities(capabilities []PlatformTunnelCapability, build BuildIdentity) ([]PlatformTunnelCapability, error) {
	snapshot := clonePlatformTunnelCapabilities(capabilities)
	if len(snapshot) == 0 {
		snapshot = defaultPlatformTunnelCapabilities(build)
	} else {
		for index := range snapshot {
			if len(snapshot[index].SupportedUnderlayRoutePolicies) == 0 &&
				snapshot[index].Mode == PlatformTunnelModeAndroidVPNService {
				snapshot[index].SupportedUnderlayRoutePolicies = []PlatformTunnelUnderlayRoutePolicy{
					PlatformTunnelUnderlayRoutePolicyStandard,
				}
			}
			if len(snapshot[index].ExecutionPlans) == 0 {
				snapshot[index].ExecutionPlans = defaultRuntimeExecutionPlansForPlatformTunnel(snapshot[index])
			}
		}
	}
	if err := validatePlatformTunnelCapabilities(snapshot, build); err != nil {
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
		if len(capability.SupportedUnderlayRoutePolicies) > 0 {
			copyCapability.SupportedUnderlayRoutePolicies = append([]PlatformTunnelUnderlayRoutePolicy(nil), capability.SupportedUnderlayRoutePolicies...)
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
	if mode == PlatformTunnelModeAndroidVPNService {
		capabilities[0].SupportedUnderlayRoutePolicies = []PlatformTunnelUnderlayRoutePolicy{
			PlatformTunnelUnderlayRoutePolicyStandard,
		}
	}
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

func validatePlatformTunnelCapabilities(capabilities []PlatformTunnelCapability, build BuildIdentity) error {
	seenModes := make(map[PlatformTunnelMode]struct{}, len(capabilities))
	targetMode, constrainTargetMode := defaultPlatformTunnelMode(build)
	for _, capability := range capabilities {
		if err := validatePlatformTunnelCapability(capability); err != nil {
			return err
		}
		if constrainTargetMode && capability.Mode != targetMode {
			return fmt.Errorf(
				"build target %s cannot report platform tunnel mode %s; want %s",
				hostTargetLabel(build),
				capability.Mode,
				targetMode,
			)
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
	seenUnderlayPolicies := make(map[PlatformTunnelUnderlayRoutePolicy]struct{}, len(capability.SupportedUnderlayRoutePolicies))
	for _, policy := range capability.SupportedUnderlayRoutePolicies {
		if !isKnownPlatformTunnelUnderlayRoutePolicy(policy) {
			return fmt.Errorf("mode %s reports unknown supported underlay_route_policy %q", capability.Mode, policy)
		}
		if _, exists := seenUnderlayPolicies[policy]; exists {
			return fmt.Errorf("mode %s reports duplicate supported underlay_route_policy %q", capability.Mode, policy)
		}
		seenUnderlayPolicies[policy] = struct{}{}
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
	if strings.TrimSpace(string(result.UnderlayRoutePolicy)) != "" &&
		!isKnownPlatformTunnelUnderlayRoutePolicy(result.UnderlayRoutePolicy) {
		return fmt.Errorf("startup result for mode %s reports unknown underlay_route_policy %q", result.Mode, result.UnderlayRoutePolicy)
	}
	if strings.TrimSpace(result.SessionID) != "" && result.StartupAttemptID != "" {
		return fmt.Errorf("startup result for mode %s reports session_id together with startup_attempt_id", result.Mode)
	}
	if len(result.UnderlayRouteExclusions) > 0 &&
		result.UnderlayRoutePolicy != PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		return fmt.Errorf("startup result for mode %s reports underlay_route_exclusions without preserve_active_local_network", result.Mode)
	}
	if result.ExecutionPlan != nil {
		if err := validateRuntimeExecutionPlan(*result.ExecutionPlan); err != nil {
			return fmt.Errorf("startup result for mode %s reports invalid execution_plan: %w", result.Mode, err)
		}
	}
	if result.ProviderTransportCompatibility != nil {
		if err := validateProviderTransportCompatibilityFailure(*result.ProviderTransportCompatibility); err != nil {
			return fmt.Errorf("startup result for mode %s reports invalid provider_transport_compatibility: %w", result.Mode, err)
		}
	}
	if result.RemoteIngress != nil {
		if err := validateRuntimeRemoteIngressDiagnostics(*result.RemoteIngress); err != nil {
			return fmt.Errorf("startup result for mode %s reports invalid remote_ingress: %w", result.Mode, err)
		}
	}
	if result.Dataplane != nil {
		if err := validatePlatformTunnelDataplaneEvidence(*result.Dataplane); err != nil {
			return fmt.Errorf("startup result for mode %s reports invalid dataplane evidence: %w", result.Mode, err)
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
		if strings.TrimSpace(result.SessionID) == "" {
			return fmt.Errorf("startup result for mode %s is ready but session_id is empty", result.Mode)
		}
		if result.Mode == PlatformTunnelModeWindowsWintun {
			if result.Dataplane == nil {
				return fmt.Errorf("startup result for mode %s is ready but missing dataplane evidence", result.Mode)
			}
			if !result.Dataplane.HostAttached ||
				!result.Dataplane.WireGuardHandshakeFresh ||
				!result.Dataplane.BidirectionalTrafficVerified {
				return fmt.Errorf("startup result for mode %s is ready but dataplane evidence is incomplete", result.Mode)
			}
		}
		return nil
	}
	if strings.TrimSpace(result.SessionID) != "" {
		return fmt.Errorf("startup result for mode %s is not ready but still reports session_id %q", result.Mode, result.SessionID)
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
					UnderlayRoutePolicy: req.UnderlayRoutePolicy,
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
					UnderlayRoutePolicy: req.UnderlayRoutePolicy,
					Message:             firstNonEmpty(selectedPlan.Message, capability.Message),
				}, nil
			}
			return PlatformTunnelStartResult{
				Mode:                req.Mode,
				ExecutionPlan:       cloneRuntimeExecutionPlan(&selectedPlan.Plan),
				Ready:               false,
				Stage:               PlatformTunnelStartupStageHostBringup,
				MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
				UnderlayRoutePolicy: req.UnderlayRoutePolicy,
				Message:             fmt.Sprintf("Platform tunnel mode %s documents execution plan %s/%s/%s/%s but this host does not implement startup yet.", req.Mode, selectedPlan.Plan.AccessMethod, selectedPlan.Plan.CarrierFamily, selectedPlan.Plan.EngineFamily, selectedPlan.Plan.HostAdapter),
			}, nil
		}

		return PlatformTunnelStartResult{
			Mode:                req.Mode,
			ExecutionPlan:       cloneRuntimeExecutionPlan(req.ExecutionPlan),
			Ready:               false,
			Stage:               PlatformTunnelStartupStageCapabilityCheck,
			MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
			UnderlayRoutePolicy: req.UnderlayRoutePolicy,
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
		PlatformTunnelPrerequisiteHostImplementation,
		PlatformTunnelPrerequisiteTransportProfile,
		PlatformTunnelPrerequisiteDataplaneEvidence:
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

func isKnownPlatformTunnelUnderlayRoutePolicy(policy PlatformTunnelUnderlayRoutePolicy) bool {
	switch policy {
	case PlatformTunnelUnderlayRoutePolicyStandard,
		PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork:
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
		PlatformTunnelStartupStageProfileValidate,
		PlatformTunnelStartupStageRouteValidate,
		PlatformTunnelStartupStageHostBringup,
		PlatformTunnelStartupStageRuntimeAttach,
		PlatformTunnelStartupStageDataplaneVerify:
		return true
	default:
		return false
	}
}

func validatePlatformTunnelDataplaneEvidence(evidence PlatformTunnelDataplaneEvidence) error {
	if evidence.WireGuardRxBytesDelta < 0 {
		return fmt.Errorf("wireguard_rx_bytes_delta is negative")
	}
	if evidence.WireGuardTxBytesDelta < 0 {
		return fmt.Errorf("wireguard_tx_bytes_delta is negative")
	}
	if evidence.WintunReceivedBytesDelta < 0 {
		return fmt.Errorf("wintun_received_bytes_delta is negative")
	}
	if evidence.BidirectionalTrafficVerified {
		if !evidence.HostAttached {
			return fmt.Errorf("bidirectional evidence requires host_attached=true")
		}
		if !evidence.WireGuardHandshakeFresh {
			return fmt.Errorf("bidirectional evidence requires wireguard_handshake_fresh=true")
		}
		if strings.TrimSpace(evidence.RemoteEgressIP) == "" {
			return fmt.Errorf("bidirectional evidence requires remote_egress_ip")
		}
	}
	return nil
}

func hostTargetLabel(build BuildIdentity) string {
	if target := strings.TrimSpace(build.Target); target != "" {
		return target
	}
	return runtime.GOOS
}

func normalizePlatformTunnelStartRequest(req PlatformTunnelStartRequest) (PlatformTunnelStartRequest, error) {
	normalized := req
	normalized.ResolutionID = strings.TrimSpace(normalized.ResolutionID)
	if normalized.TransportProfile != nil {
		ref := *normalized.TransportProfile
		ref.ProfileID = strings.TrimSpace(ref.ProfileID)
		ref.Kind = TransportProfileKind(strings.TrimSpace(string(ref.Kind)))
		ref.DefaultScopeID = strings.TrimSpace(ref.DefaultScopeID)
		normalized.TransportProfile = &ref
	}
	if normalized.ProviderTransportCompatibility != nil {
		ref := cloneProviderTransportCompatibilityStartupReference(normalized.ProviderTransportCompatibility)
		ref.CandidateID = strings.TrimSpace(ref.CandidateID)
		if ref.Source != nil {
			ref.Source.ProviderID = strings.TrimSpace(ref.Source.ProviderID)
			ref.Source.SourceID = strings.TrimSpace(ref.Source.SourceID)
			ref.Source.ResolutionID = strings.TrimSpace(ref.Source.ResolutionID)
			if normalized.ResolutionID == "" {
				normalized.ResolutionID = ref.Source.ResolutionID
			}
		}
		if ref.Artifact != nil {
			ref.Artifact.ProviderID = strings.TrimSpace(ref.Artifact.ProviderID)
			ref.Artifact.ResolutionID = strings.TrimSpace(ref.Artifact.ResolutionID)
			if normalized.ResolutionID == "" {
				normalized.ResolutionID = ref.Artifact.ResolutionID
			}
		}
		if normalized.ExecutionPlan == nil {
			normalized.ExecutionPlan = cloneRuntimeExecutionPlan(ref.ExecutionPlan)
		}
		if normalized.TransportProfile == nil {
			normalized.TransportProfile = cloneTransportProfileReference(ref.TransportProfile)
		}
		normalized.ProviderTransportCompatibility = ref
	}
	if normalized.RuntimeDefaults != nil {
		defaults := *normalized.RuntimeDefaults
		defaults.ListenAddr = strings.TrimSpace(defaults.ListenAddr)
		defaults.PeerAddr = strings.TrimSpace(defaults.PeerAddr)
		defaults.TURNServer = strings.TrimSpace(defaults.TURNServer)
		defaults.TURNPort = strings.TrimSpace(defaults.TURNPort)
		defaults.BindInterface = strings.TrimSpace(defaults.BindInterface)
		defaults.LogLevel = strings.TrimSpace(defaults.LogLevel)
		normalized.RuntimeDefaults = &defaults
	}

	if req.Mode != PlatformTunnelModeAndroidVPNService &&
		req.Mode != PlatformTunnelModeWindowsWintun &&
		req.Mode != PlatformTunnelModeLinuxTun {
		if strings.TrimSpace(string(req.ApplicationRoutingPolicy)) != "" ||
			len(req.AllowedPackages) > 0 ||
			len(req.DisallowedPackages) > 0 {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: mode %s does not accept application routing policy", ErrPlatformTunnelAppRoutingPolicyInvalid, req.Mode)
		}
		if strings.TrimSpace(string(req.UnderlayRoutePolicy)) != "" {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: mode %s does not accept underlay_route_policy", ErrPlatformTunnelUnderlayRoutePolicyInvalid, req.Mode)
		}
		return normalized, nil
	}

	if req.Mode == PlatformTunnelModeWindowsWintun || req.Mode == PlatformTunnelModeLinuxTun {
		if strings.TrimSpace(string(normalized.ApplicationRoutingPolicy)) != "" ||
			len(normalized.AllowedPackages) > 0 ||
			len(normalized.DisallowedPackages) > 0 {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: mode %s does not accept application routing policy", ErrPlatformTunnelAppRoutingPolicyInvalid, req.Mode)
		}
		if strings.TrimSpace(string(normalized.UnderlayRoutePolicy)) == "" {
			normalized.UnderlayRoutePolicy = PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork
		}
		if !isKnownPlatformTunnelUnderlayRoutePolicy(normalized.UnderlayRoutePolicy) {
			return PlatformTunnelStartRequest{}, fmt.Errorf("%w: unknown underlay_route_policy %q", ErrPlatformTunnelUnderlayRoutePolicyInvalid, normalized.UnderlayRoutePolicy)
		}
		return normalized, nil
	}

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
	if strings.TrimSpace(string(normalized.UnderlayRoutePolicy)) == "" {
		normalized.UnderlayRoutePolicy = PlatformTunnelUnderlayRoutePolicyStandard
	}
	if !isKnownPlatformTunnelUnderlayRoutePolicy(normalized.UnderlayRoutePolicy) {
		return PlatformTunnelStartRequest{}, fmt.Errorf("%w: unknown underlay_route_policy %q", ErrPlatformTunnelUnderlayRoutePolicyInvalid, normalized.UnderlayRoutePolicy)
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

func normalizePlatformTunnelStopRequest(req PlatformTunnelStopRequest) (PlatformTunnelStopRequest, error) {
	normalized := req
	normalized.Mode = PlatformTunnelMode(strings.TrimSpace(string(normalized.Mode)))
	if normalized.Mode == "" {
		return PlatformTunnelStopRequest{}, ErrPlatformTunnelModeRequired
	}
	if !isKnownPlatformTunnelMode(normalized.Mode) {
		return PlatformTunnelStopRequest{}, ErrPlatformTunnelModeUnknown
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
