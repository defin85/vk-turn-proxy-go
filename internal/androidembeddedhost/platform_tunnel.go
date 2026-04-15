package androidembeddedhost

import (
	"context"
	"errors"
	"fmt"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

type platformTunnelController interface {
	Capability() clientcontrol.PlatformTunnelCapability
	Start(context.Context, clientcontrol.PlatformTunnelStartRequest) (clientcontrol.PlatformTunnelStartResult, error)
}

type androidVPNServiceLifecycle interface {
	AcquirePermission(context.Context) error
	ValidateRoutePolicy(context.Context) error
	BringupHost(context.Context) error
	AttachRuntime(context.Context) error
	Cleanup(context.Context) error
}

type androidVPNServiceController struct {
	capability clientcontrol.PlatformTunnelCapability
	lifecycle  androidVPNServiceLifecycle
}

type androidVPNServiceRoutePolicyError struct {
	prerequisite clientcontrol.PlatformTunnelPrerequisite
	message      string
}

func (e *androidVPNServiceRoutePolicyError) Error() string {
	if e == nil {
		return ""
	}
	if strings.TrimSpace(e.message) != "" {
		return e.message
	}
	return fmt.Sprintf("android vpn route policy requires %s", e.prerequisite)
}

func defaultAndroidVPNServiceController(build clientcontrol.BuildIdentity) platformTunnelController {
	message := fmt.Sprintf(
		"The %s host does not yet implement platform tunnel startup for mode %s.",
		firstNonEmpty(strings.TrimSpace(build.Target), "android"),
		clientcontrol.PlatformTunnelModeAndroidVPNService,
	)
	return newAndroidVPNServiceController(clientcontrol.PlatformTunnelCapability{
		Mode:                clientcontrol.PlatformTunnelModeAndroidVPNService,
		Available:           false,
		MissingPrerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		Message:             message,
	}, nil)
}

func newAndroidVPNServiceController(
	capability clientcontrol.PlatformTunnelCapability,
	lifecycle androidVPNServiceLifecycle,
) platformTunnelController {
	normalized := capability
	if normalized.Mode == "" {
		normalized.Mode = clientcontrol.PlatformTunnelModeAndroidVPNService
	}
	if len(normalized.ExecutionPlans) == 0 {
		normalized.ExecutionPlans = androidVPNServiceExecutionPlans(normalized.Available, normalized.Message)
	}
	if !normalized.Available && strings.TrimSpace(string(normalized.MissingPrerequisite)) == "" {
		normalized.MissingPrerequisite = clientcontrol.PlatformTunnelPrerequisiteHostImplementation
	}
	return &androidVPNServiceController{
		capability: normalized,
		lifecycle:  lifecycle,
	}
}

func (c *androidVPNServiceController) Capability() clientcontrol.PlatformTunnelCapability {
	if c == nil {
		return clientcontrol.PlatformTunnelCapability{}
	}
	return clonePlatformTunnelCapability(c.capability)
}

func (c *androidVPNServiceController) Start(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
) (clientcontrol.PlatformTunnelStartResult, error) {
	capability := c.Capability()
	if req.Mode != capability.Mode {
		return capabilityCheckFailure(
			req.Mode,
			nil,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			fmt.Sprintf("android embedded host does not publish platform tunnel mode %s", req.Mode),
		), nil
	}

	selectedPlan, err := selectAndroidVPNServiceExecutionPlan(capability.ExecutionPlans, req.ExecutionPlan)
	if err != nil {
		return capabilityCheckFailure(
			req.Mode,
			nil,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			err.Error(),
		), nil
	}
	selectedPlanPtr := cloneRuntimeExecutionPlan(selectedPlan)
	if !capability.Available {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlanPtr,
			capability.MissingPrerequisite,
			firstNonEmpty(strings.TrimSpace(capability.Message), unavailableExecutionPlanMessage(capability, selectedPlan)),
		), nil
	}
	if c.lifecycle == nil {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			"android embedded host reports android_vpn_service support without a packaged lifecycle implementation",
		), nil
	}

	if err := c.lifecycle.AcquirePermission(ctx); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			clientcontrol.PlatformTunnelPrerequisitePermission,
			err.Error(),
		)
	}

	cleanupRequired := true
	if err := c.lifecycle.ValidateRoutePolicy(ctx); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStageRouteValidate,
			routePolicyPrerequisite(err),
			withCleanupMessage(ctx, c.lifecycle, cleanupRequired, err.Error()),
		)
	}
	if err := c.lifecycle.BringupHost(ctx); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStageHostBringup,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			withCleanupMessage(ctx, c.lifecycle, cleanupRequired, err.Error()),
		)
	}
	if err := c.lifecycle.AttachRuntime(ctx); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			withCleanupMessage(ctx, c.lifecycle, cleanupRequired, err.Error()),
		)
	}

	return clientcontrol.PlatformTunnelStartResult{
		Mode:          req.Mode,
		ExecutionPlan: selectedPlanPtr,
		Ready:         true,
	}, nil
}

func capabilityCheckFailure(
	mode clientcontrol.PlatformTunnelMode,
	plan *clientcontrol.RuntimeExecutionPlan,
	prerequisite clientcontrol.PlatformTunnelPrerequisite,
	message string,
) clientcontrol.PlatformTunnelStartResult {
	if strings.TrimSpace(string(prerequisite)) == "" {
		prerequisite = clientcontrol.PlatformTunnelPrerequisiteHostImplementation
	}
	return clientcontrol.PlatformTunnelStartResult{
		Mode:                mode,
		ExecutionPlan:       cloneRuntimeExecutionPlan(plan),
		Ready:               false,
		Stage:               clientcontrol.PlatformTunnelStartupStageCapabilityCheck,
		MissingPrerequisite: prerequisite,
		Message:             strings.TrimSpace(message),
	}
}

func startFailureResult(
	mode clientcontrol.PlatformTunnelMode,
	plan *clientcontrol.RuntimeExecutionPlan,
	stage clientcontrol.PlatformTunnelStartupStage,
	prerequisite clientcontrol.PlatformTunnelPrerequisite,
	message string,
) (clientcontrol.PlatformTunnelStartResult, error) {
	result := clientcontrol.PlatformTunnelStartResult{
		Mode:                mode,
		ExecutionPlan:       cloneRuntimeExecutionPlan(plan),
		Ready:               false,
		Stage:               stage,
		MissingPrerequisite: prerequisite,
		Message:             strings.TrimSpace(message),
	}
	return clientcontrol.PlatformTunnelStartResult{}, &clientcontrol.PlatformTunnelStartError{Result: result}
}

func withCleanupMessage(
	ctx context.Context,
	lifecycle androidVPNServiceLifecycle,
	cleanupRequired bool,
	message string,
) string {
	message = strings.TrimSpace(message)
	if !cleanupRequired || lifecycle == nil {
		return message
	}
	if err := lifecycle.Cleanup(ctx); err != nil {
		if message == "" {
			return fmt.Sprintf("cleanup failed: %v", err)
		}
		return fmt.Sprintf("%s; cleanup failed: %v", message, err)
	}
	return message
}

func routePolicyPrerequisite(err error) clientcontrol.PlatformTunnelPrerequisite {
	var routeErr *androidVPNServiceRoutePolicyError
	if errors.As(err, &routeErr) && strings.TrimSpace(string(routeErr.prerequisite)) != "" {
		return routeErr.prerequisite
	}
	return clientcontrol.PlatformTunnelPrerequisiteRouteExclusion
}

func androidVPNServiceExecutionPlans(
	available bool,
	message string,
) []clientcontrol.RuntimeExecutionPlanDescriptor {
	supportState := clientcontrol.RuntimeExecutionPlanSupportStateUnavailable
	if available {
		supportState = clientcontrol.RuntimeExecutionPlanSupportStateSupported
	}
	return []clientcontrol.RuntimeExecutionPlanDescriptor{{
		Plan: clientcontrol.RuntimeExecutionPlan{
			AccessMethod:  clientcontrol.RuntimeAccessMethodTURNCredentials,
			CarrierFamily: clientcontrol.RuntimeCarrierFamilyTURNDatagram,
			EngineFamily:  clientcontrol.RuntimeEngineFamilyWireGuardNative,
			HostAdapter:   clientcontrol.RuntimeHostAdapterAndroidVPNService,
		},
		SupportState:         supportState,
		RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
		Default:              true,
		Message:              strings.TrimSpace(message),
	}}
}

func selectAndroidVPNServiceExecutionPlan(
	descriptors []clientcontrol.RuntimeExecutionPlanDescriptor,
	requested *clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.RuntimeExecutionPlan, error) {
	if len(descriptors) == 0 {
		if requested == nil {
			return nil, fmt.Errorf("android_vpn_service does not advertise any execution plans")
		}
		return nil, fmt.Errorf("requested android_vpn_service execution plan is not advertised by this host")
	}
	if requested != nil {
		for _, descriptor := range descriptors {
			if runtimeExecutionPlanEquals(descriptor.Plan, *requested) {
				return cloneRuntimeExecutionPlan(&descriptor.Plan), nil
			}
		}
		return nil, fmt.Errorf("requested android_vpn_service execution plan is not advertised by this host")
	}
	for _, descriptor := range descriptors {
		if descriptor.Default {
			return cloneRuntimeExecutionPlan(&descriptor.Plan), nil
		}
	}
	if len(descriptors) == 1 {
		return cloneRuntimeExecutionPlan(&descriptors[0].Plan), nil
	}
	return nil, fmt.Errorf("android_vpn_service startup requires an explicit execution plan selection")
}

func unavailableExecutionPlanMessage(
	capability clientcontrol.PlatformTunnelCapability,
	plan *clientcontrol.RuntimeExecutionPlan,
) string {
	for _, descriptor := range capability.ExecutionPlans {
		if plan != nil && runtimeExecutionPlanEquals(descriptor.Plan, *plan) && strings.TrimSpace(descriptor.Message) != "" {
			return strings.TrimSpace(descriptor.Message)
		}
	}
	return strings.TrimSpace(capability.Message)
}

func runtimeExecutionPlanEquals(
	left clientcontrol.RuntimeExecutionPlan,
	right clientcontrol.RuntimeExecutionPlan,
) bool {
	return left.AccessMethod == right.AccessMethod &&
		left.CarrierFamily == right.CarrierFamily &&
		left.EngineFamily == right.EngineFamily &&
		left.HostAdapter == right.HostAdapter
}

func cloneRuntimeExecutionPlan(plan *clientcontrol.RuntimeExecutionPlan) *clientcontrol.RuntimeExecutionPlan {
	if plan == nil {
		return nil
	}
	clone := *plan
	return &clone
}

func clonePlatformTunnelCapability(capability clientcontrol.PlatformTunnelCapability) clientcontrol.PlatformTunnelCapability {
	clone := capability
	if len(capability.SatisfiedPrerequisites) > 0 {
		clone.SatisfiedPrerequisites = append([]clientcontrol.PlatformTunnelPrerequisite(nil), capability.SatisfiedPrerequisites...)
	}
	if len(capability.ExecutionPlans) > 0 {
		clone.ExecutionPlans = append([]clientcontrol.RuntimeExecutionPlanDescriptor(nil), capability.ExecutionPlans...)
	}
	return clone
}

func newAndroidRouteExclusionError(message string) error {
	return &androidVPNServiceRoutePolicyError{
		prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
		message:      strings.TrimSpace(message),
	}
}

func newAndroidDNSBypassError(message string) error {
	return &androidVPNServiceRoutePolicyError{
		prerequisite: clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
		message:      strings.TrimSpace(message),
	}
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}
