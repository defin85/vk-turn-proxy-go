package windowsdesktophost

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

var (
	errMissingExecutionPlan   = errors.New("windows wintun startup requires an execution plan")
	errMissingResolutionID    = errors.New("windows wintun startup requires resolution_id")
	errMissingRuntimeDefaults = errors.New("windows wintun startup requires runtime_defaults")
)

type windowsWintunLeaseProvider func(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.WireGuardTurnExecutionLease, error)

type windowsRoutePolicyState struct {
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy
	Exclusions          []string
}

type WindowsWintunLifecycle interface {
	CheckDriver(context.Context, clientcontrol.PlatformTunnelStartRequest) error
	ValidateRoutePolicy(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease) (*windowsRoutePolicyState, error)
	BringupHost(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease, *windowsRoutePolicyState) error
	AttachRuntime(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease, *windowsRoutePolicyState) error
	Cleanup(context.Context) error
}

type windowsWintunRoutePolicyError struct {
	prerequisite clientcontrol.PlatformTunnelPrerequisite
	message      string
}

func (e *windowsWintunRoutePolicyError) Error() string {
	if e == nil {
		return ""
	}
	if strings.TrimSpace(e.message) != "" {
		return e.message
	}
	return fmt.Sprintf("windows wintun route policy requires %s", e.prerequisite)
}

type windowsWintunController struct {
	capability clientcontrol.PlatformTunnelCapability
	lifecycle  WindowsWintunLifecycle

	mu      sync.Mutex
	leaseFn windowsWintunLeaseProvider
}

func newWindowsWintunController(
	capability clientcontrol.PlatformTunnelCapability,
	lifecycle WindowsWintunLifecycle,
) *windowsWintunController {
	normalized := capability
	if normalized.Mode == "" {
		normalized.Mode = clientcontrol.PlatformTunnelModeWindowsWintun
	}
	if len(normalized.ExecutionPlans) == 0 {
		normalized.ExecutionPlans = []clientcontrol.RuntimeExecutionPlanDescriptor{{
			Plan: clientcontrol.RuntimeExecutionPlan{
				AccessMethod:  clientcontrol.RuntimeAccessMethodTURNCredentials,
				CarrierFamily: clientcontrol.RuntimeCarrierFamilyTURNDatagram,
				EngineFamily:  clientcontrol.RuntimeEngineFamilyWireGuardNative,
				HostAdapter:   clientcontrol.RuntimeHostAdapterWindowsWintun,
			},
			SupportState:         supportStateForCapability(normalized.Available),
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
			Default:              true,
			Message:              strings.TrimSpace(normalized.Message),
		}}
	}
	return &windowsWintunController{
		capability: normalized,
		lifecycle:  lifecycle,
	}
}

func defaultWindowsWintunCapability(build clientcontrol.BuildIdentity) clientcontrol.PlatformTunnelCapability {
	return clientcontrol.PlatformTunnelCapability{
		Mode:                clientcontrol.PlatformTunnelModeWindowsWintun,
		Available:           false,
		MissingPrerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		Message: fmt.Sprintf(
			"The %s host does not yet implement platform tunnel startup for mode %s.",
			firstNonEmpty(strings.TrimSpace(build.Target), "windows/amd64"),
			clientcontrol.PlatformTunnelModeWindowsWintun,
		),
		SupportedUnderlayRoutePolicies: []clientcontrol.PlatformTunnelUnderlayRoutePolicy{
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		},
	}
}

func supportedWindowsWintunCapability(message string) clientcontrol.PlatformTunnelCapability {
	return clientcontrol.PlatformTunnelCapability{
		Mode:      clientcontrol.PlatformTunnelModeWindowsWintun,
		Available: true,
		SatisfiedPrerequisites: []clientcontrol.PlatformTunnelPrerequisite{
			clientcontrol.PlatformTunnelPrerequisiteDriver,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
		},
		SupportedUnderlayRoutePolicies: []clientcontrol.PlatformTunnelUnderlayRoutePolicy{
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		},
		Message: strings.TrimSpace(message),
	}
}

func supportStateForCapability(available bool) clientcontrol.RuntimeExecutionPlanSupportState {
	if available {
		return clientcontrol.RuntimeExecutionPlanSupportStateSupported
	}
	return clientcontrol.RuntimeExecutionPlanSupportStateUnavailable
}

func (c *windowsWintunController) Capability() clientcontrol.PlatformTunnelCapability {
	if c == nil {
		return clientcontrol.PlatformTunnelCapability{}
	}
	return clonePlatformTunnelCapability(c.capability)
}

func (c *windowsWintunController) Start(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
) (clientcontrol.PlatformTunnelStartResult, error) {
	if strings.TrimSpace(string(req.UnderlayRoutePolicy)) == "" {
		req.UnderlayRoutePolicy = clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork
	}
	capability := c.Capability()
	if req.Mode != capability.Mode {
		return capabilityCheckFailure(
			req.Mode,
			nil,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			fmt.Sprintf("windows desktop host does not publish platform tunnel mode %s", req.Mode),
		), nil
	}
	selectedPlan, err := selectWindowsExecutionPlan(capability.ExecutionPlans, req.ExecutionPlan)
	if err != nil {
		return capabilityCheckFailure(
			req.Mode,
			nil,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			err.Error(),
		), nil
	}
	if !capability.Available {
		return capabilityCheckFailure(
			req.Mode,
			cloneRuntimeExecutionPlan(selectedPlan),
			capability.MissingPrerequisite,
			req.UnderlayRoutePolicy,
			firstNonEmpty(strings.TrimSpace(capability.Message), unavailableExecutionPlanMessage(capability, selectedPlan)),
		), nil
	}
	if c.lifecycle == nil {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			"windows desktop host reports windows_wintun support without a packaged lifecycle implementation",
		), nil
	}
	if !supportsWindowsUnderlayRoutePolicy(capability, req.UnderlayRoutePolicy) {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			req.UnderlayRoutePolicy,
			fmt.Sprintf(
				"windows desktop host does not advertise underlay_route_policy %s for mode %s",
				req.UnderlayRoutePolicy,
				req.Mode,
			),
		), nil
	}
	if err := c.lifecycle.CheckDriver(ctx, req); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageDriverCheck,
			clientcontrol.PlatformTunnelPrerequisiteDriver,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}

	leaseFn := c.wireGuardTurnLeaseProvider()
	if leaseFn == nil {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			"windows desktop host cannot materialize the strict TURN datagram WireGuard runtime lease",
		)
	}
	lease, err := leaseFn(ctx, req, selectedPlan)
	if err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}

	routeState, err := c.lifecycle.ValidateRoutePolicy(ctx, req, selectedPlan, lease)
	if err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageRouteValidate,
			routePolicyPrerequisite(err),
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	if err := c.lifecycle.BringupHost(ctx, req, selectedPlan, lease, routeState); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageHostBringup,
			clientcontrol.PlatformTunnelPrerequisiteDriver,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	if err := c.lifecycle.AttachRuntime(ctx, req, selectedPlan, lease, routeState); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	result := clientcontrol.PlatformTunnelStartResult{
		Mode:                    req.Mode,
		ExecutionPlan:           cloneRuntimeExecutionPlan(selectedPlan),
		Ready:                   true,
		UnderlayRoutePolicy:     req.UnderlayRoutePolicy,
		UnderlayRouteExclusions: append([]string(nil), routeState.Exclusions...),
	}
	return result, nil
}

func (c *windowsWintunController) Stop(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStopRequest,
) (clientcontrol.PlatformTunnelStopResult, error) {
	capability := c.Capability()
	if req.Mode != capability.Mode {
		return clientcontrol.PlatformTunnelStopResult{}, fmt.Errorf(
			"windows desktop host does not publish platform tunnel mode %s",
			req.Mode,
		)
	}
	if c.lifecycle == nil {
		return clientcontrol.PlatformTunnelStopResult{}, fmt.Errorf(
			"windows desktop host does not implement stop for %s",
			req.Mode,
		)
	}
	if err := c.lifecycle.Cleanup(ctx); err != nil {
		return clientcontrol.PlatformTunnelStopResult{}, err
	}
	return clientcontrol.PlatformTunnelStopResult{
		Mode:    req.Mode,
		Stopped: true,
		Message: "Windows wintun disconnected.",
	}, nil
}

func (c *windowsWintunController) setWireGuardTurnLeaseProvider(fn windowsWintunLeaseProvider) {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.leaseFn = fn
}

func (c *windowsWintunController) wireGuardTurnLeaseProvider() windowsWintunLeaseProvider {
	if c == nil {
		return nil
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.leaseFn
}

func capabilityCheckFailure(
	mode clientcontrol.PlatformTunnelMode,
	plan *clientcontrol.RuntimeExecutionPlan,
	prerequisite clientcontrol.PlatformTunnelPrerequisite,
	underlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy,
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
		UnderlayRoutePolicy: underlayRoutePolicy,
		Message:             strings.TrimSpace(message),
	}
}

func startFailureResult(
	mode clientcontrol.PlatformTunnelMode,
	plan *clientcontrol.RuntimeExecutionPlan,
	stage clientcontrol.PlatformTunnelStartupStage,
	prerequisite clientcontrol.PlatformTunnelPrerequisite,
	underlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy,
	message string,
) (clientcontrol.PlatformTunnelStartResult, error) {
	result := clientcontrol.PlatformTunnelStartResult{
		Mode:                mode,
		ExecutionPlan:       cloneRuntimeExecutionPlan(plan),
		Ready:               false,
		Stage:               stage,
		MissingPrerequisite: prerequisite,
		UnderlayRoutePolicy: underlayRoutePolicy,
		Message:             strings.TrimSpace(message),
	}
	return clientcontrol.PlatformTunnelStartResult{}, &clientcontrol.PlatformTunnelStartError{Result: result}
}

func routePolicyPrerequisite(err error) clientcontrol.PlatformTunnelPrerequisite {
	var routeErr *windowsWintunRoutePolicyError
	if errors.As(err, &routeErr) && strings.TrimSpace(string(routeErr.prerequisite)) != "" {
		return routeErr.prerequisite
	}
	return clientcontrol.PlatformTunnelPrerequisiteRouteExclusion
}

func selectWindowsExecutionPlan(
	descriptors []clientcontrol.RuntimeExecutionPlanDescriptor,
	requested *clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.RuntimeExecutionPlan, error) {
	if len(descriptors) == 0 {
		if requested == nil {
			return nil, fmt.Errorf("windows_wintun does not advertise any execution plans")
		}
		return nil, fmt.Errorf("requested windows_wintun execution plan is not advertised by this host")
	}
	if requested != nil {
		for _, descriptor := range descriptors {
			if runtimeExecutionPlanEquals(descriptor.Plan, *requested) {
				return cloneRuntimeExecutionPlan(&descriptor.Plan), nil
			}
		}
		return nil, fmt.Errorf("requested windows_wintun execution plan is not advertised by this host")
	}
	for _, descriptor := range descriptors {
		if descriptor.Default {
			return cloneRuntimeExecutionPlan(&descriptor.Plan), nil
		}
	}
	if len(descriptors) == 1 {
		return cloneRuntimeExecutionPlan(&descriptors[0].Plan), nil
	}
	return nil, fmt.Errorf("windows_wintun startup requires an explicit execution plan selection")
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

func supportsWindowsUnderlayRoutePolicy(
	capability clientcontrol.PlatformTunnelCapability,
	policy clientcontrol.PlatformTunnelUnderlayRoutePolicy,
) bool {
	for _, supported := range capability.SupportedUnderlayRoutePolicies {
		if supported == policy {
			return true
		}
	}
	return false
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
	if len(capability.SupportedUnderlayRoutePolicies) > 0 {
		clone.SupportedUnderlayRoutePolicies = append([]clientcontrol.PlatformTunnelUnderlayRoutePolicy(nil), capability.SupportedUnderlayRoutePolicies...)
	}
	if len(capability.ExecutionPlans) > 0 {
		clone.ExecutionPlans = append([]clientcontrol.RuntimeExecutionPlanDescriptor(nil), capability.ExecutionPlans...)
	}
	return clone
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

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}
