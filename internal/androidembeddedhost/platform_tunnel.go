package androidembeddedhost

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

type platformTunnelController interface {
	Capability() clientcontrol.PlatformTunnelCapability
	Start(context.Context, clientcontrol.PlatformTunnelStartRequest) (clientcontrol.PlatformTunnelStartResult, error)
	Resume(context.Context, clientcontrol.PlatformTunnelResumeRequest) (clientcontrol.PlatformTunnelStartResult, error)
	Stop(context.Context, clientcontrol.PlatformTunnelStopRequest) (clientcontrol.PlatformTunnelStopResult, error)
}

type AndroidVPNServiceLifecycle interface {
	AcquirePermission(context.Context, clientcontrol.PlatformTunnelStartRequest) error
	ResumeAfterPermission(context.Context, string, clientcontrol.PlatformTunnelStartRequest) error
	ValidateRoutePolicy(context.Context, clientcontrol.PlatformTunnelStartRequest) error
	BringupHost(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease) error
	AttachRuntime(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease) error
	Cleanup(context.Context) error
}

type androidVPNServiceLeaseProvider func(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.WireGuardTurnExecutionLease, error)

type androidVPNServiceController struct {
	capability clientcontrol.PlatformTunnelCapability
	lifecycle  AndroidVPNServiceLifecycle
	leaseFn    androidVPNServiceLeaseProvider
	mu         sync.Mutex
	nextID     uint64
	attempts   map[string]androidVPNServiceStartupAttempt
}

type androidVPNServiceStartupAttempt struct {
	req  clientcontrol.PlatformTunnelStartRequest
	plan *clientcontrol.RuntimeExecutionPlan
}

type androidVPNServiceRoutePolicyError struct {
	prerequisite clientcontrol.PlatformTunnelPrerequisite
	message      string
}

type androidVPNServicePermissionPendingError struct {
	attemptID string
	message   string
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

func (e *androidVPNServicePermissionPendingError) Error() string {
	if e == nil {
		return ""
	}
	if strings.TrimSpace(e.message) != "" {
		return e.message
	}
	return "android vpn permission is required before startup can continue"
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
	lifecycle AndroidVPNServiceLifecycle,
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
		attempts:   make(map[string]androidVPNServiceStartupAttempt),
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
	if strings.TrimSpace(string(req.UnderlayRoutePolicy)) == "" {
		req.UnderlayRoutePolicy = clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard
	}
	capability := c.Capability()
	if req.Mode != capability.Mode {
		return capabilityCheckFailure(
			req.Mode,
			nil,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			fmt.Sprintf("android embedded host does not publish platform tunnel mode %s", req.Mode),
		), nil
	}

	selectedPlan, err := selectAndroidVPNServiceExecutionPlan(capability.ExecutionPlans, req.ExecutionPlan)
	if err != nil {
		return capabilityCheckFailure(
			req.Mode,
			nil,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			err.Error(),
		), nil
	}
	selectedPlanPtr := cloneRuntimeExecutionPlan(selectedPlan)
	if !capability.Available {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlanPtr,
			capability.MissingPrerequisite,
			req.UnderlayRoutePolicy,
			firstNonEmpty(strings.TrimSpace(capability.Message), unavailableExecutionPlanMessage(capability, selectedPlan)),
		), nil
	}
	if c.lifecycle == nil {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			"android embedded host reports android_vpn_service support without a packaged lifecycle implementation",
		), nil
	}
	if !supportsUnderlayRoutePolicy(capability, req.UnderlayRoutePolicy) {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			req.UnderlayRoutePolicy,
			fmt.Sprintf(
				"android embedded host does not advertise underlay_route_policy %s for mode %s",
				req.UnderlayRoutePolicy,
				req.Mode,
			),
		), nil
	}

	if err := c.lifecycle.AcquirePermission(ctx, req); err != nil {
		var pending *androidVPNServicePermissionPendingError
		if errors.As(err, &pending) {
			attemptID := c.storeStartupAttempt(pending.attemptID, req, selectedPlanPtr)
			return clientcontrol.PlatformTunnelStartResult{
				Mode:                req.Mode,
				ExecutionPlan:       cloneRuntimeExecutionPlan(selectedPlanPtr),
				Ready:               false,
				Stage:               clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
				MissingPrerequisite: clientcontrol.PlatformTunnelPrerequisitePermission,
				StartupAttemptID:    attemptID,
				UnderlayRoutePolicy: req.UnderlayRoutePolicy,
				Message:             pending.Error(),
			}, nil
		}
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			clientcontrol.PlatformTunnelPrerequisitePermission,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}

	return c.finishStartup(ctx, req, selectedPlanPtr)
}

func (c *androidVPNServiceController) Resume(
	ctx context.Context,
	req clientcontrol.PlatformTunnelResumeRequest,
) (clientcontrol.PlatformTunnelStartResult, error) {
	if c.lifecycle == nil {
		return clientcontrol.PlatformTunnelStartResult{}, fmt.Errorf("android embedded host does not implement resume for android_vpn_service")
	}
	attempt, ok := c.takeStartupAttempt(req.StartupAttemptID)
	if !ok {
		return clientcontrol.PlatformTunnelStartResult{}, clientcontrol.ErrPlatformTunnelStartupAttemptNotFound
	}
	if err := c.lifecycle.ResumeAfterPermission(ctx, req.StartupAttemptID, attempt.req); err != nil {
		return startFailureResult(
			attempt.req.Mode,
			attempt.plan,
			clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			clientcontrol.PlatformTunnelPrerequisitePermission,
			attempt.req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	return c.finishStartup(ctx, attempt.req, attempt.plan)
}

func (c *androidVPNServiceController) Stop(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStopRequest,
) (clientcontrol.PlatformTunnelStopResult, error) {
	capability := c.Capability()
	if req.Mode != capability.Mode {
		return clientcontrol.PlatformTunnelStopResult{}, fmt.Errorf(
			"android embedded host does not publish platform tunnel mode %s",
			req.Mode,
		)
	}
	if c.lifecycle == nil {
		return clientcontrol.PlatformTunnelStopResult{}, fmt.Errorf(
			"android embedded host does not implement stop for %s",
			req.Mode,
		)
	}
	if err := c.lifecycle.Cleanup(ctx); err != nil {
		return clientcontrol.PlatformTunnelStopResult{}, err
	}
	c.clearStartupAttempts()
	return clientcontrol.PlatformTunnelStopResult{
		Mode:    req.Mode,
		Stopped: true,
		Message: "Android VPN Service disconnected.",
	}, nil
}

func (c *androidVPNServiceController) finishStartup(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
	selectedPlanPtr *clientcontrol.RuntimeExecutionPlan,
) (clientcontrol.PlatformTunnelStartResult, error) {
	if err := c.lifecycle.ValidateRoutePolicy(ctx, req); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStageRouteValidate,
			routePolicyPrerequisite(err),
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	var lease *clientcontrol.WireGuardTurnExecutionLease
	if selectedPlanPtr != nil &&
		selectedPlanPtr.AccessMethod == clientcontrol.RuntimeAccessMethodTURNCredentials &&
		selectedPlanPtr.CarrierFamily == clientcontrol.RuntimeCarrierFamilyTURNDatagram &&
		selectedPlanPtr.EngineFamily == clientcontrol.RuntimeEngineFamilyWireGuardNative &&
		strings.TrimSpace(string(selectedPlanPtr.HostAdapter)) != "" {
		if c.leaseFn == nil {
			return startFailureResult(
				req.Mode,
				selectedPlanPtr,
				clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
				clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
				req.UnderlayRoutePolicy,
				"android embedded host cannot materialize the strict TURN datagram WireGuard runtime lease",
			)
		}
		var err error
		lease, err = c.leaseFn(ctx, req, selectedPlanPtr)
		if err != nil {
			stage, prerequisite := leaseMaterializationFailureClassification(err)
			return startFailureResult(
				req.Mode,
				selectedPlanPtr,
				stage,
				prerequisite,
				req.UnderlayRoutePolicy,
				err.Error(),
			)
		}
	}
	if err := c.lifecycle.BringupHost(ctx, req, selectedPlanPtr, lease); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStageHostBringup,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	if err := c.lifecycle.AttachRuntime(ctx, req, selectedPlanPtr, lease); err != nil {
		return startFailureResult(
			req.Mode,
			selectedPlanPtr,
			clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}

	return clientcontrol.PlatformTunnelStartResult{
		Mode:                req.Mode,
		ExecutionPlan:       selectedPlanPtr,
		Ready:               true,
		UnderlayRoutePolicy: req.UnderlayRoutePolicy,
	}, nil
}

func (c *androidVPNServiceController) setWireGuardTurnLeaseProvider(
	leaseFn androidVPNServiceLeaseProvider,
) {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.leaseFn = leaseFn
}

func (c *androidVPNServiceController) storeStartupAttempt(
	requestedID string,
	req clientcontrol.PlatformTunnelStartRequest,
	plan *clientcontrol.RuntimeExecutionPlan,
) string {
	c.mu.Lock()
	defer c.mu.Unlock()

	attemptID := strings.TrimSpace(requestedID)
	if attemptID == "" {
		c.nextID++
		attemptID = fmt.Sprintf("android-vpn-startup-%d", c.nextID)
	}
	c.attempts[attemptID] = androidVPNServiceStartupAttempt{
		req:  req,
		plan: cloneRuntimeExecutionPlan(plan),
	}
	return attemptID
}

func (c *androidVPNServiceController) takeStartupAttempt(startupAttemptID string) (androidVPNServiceStartupAttempt, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()

	attempt, ok := c.attempts[strings.TrimSpace(startupAttemptID)]
	if !ok {
		return androidVPNServiceStartupAttempt{}, false
	}
	delete(c.attempts, strings.TrimSpace(startupAttemptID))
	return attempt, true
}

func (c *androidVPNServiceController) clearStartupAttempts() {
	c.mu.Lock()
	defer c.mu.Unlock()
	clear(c.attempts)
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

func leaseMaterializationFailureClassification(err error) (clientcontrol.PlatformTunnelStartupStage, clientcontrol.PlatformTunnelPrerequisite) {
	if errors.Is(err, clientcontrol.ErrTransportProfileStoreUnavailable) ||
		errors.Is(err, clientcontrol.ErrTransportProfileNotFound) ||
		errors.Is(err, clientcontrol.ErrTransportProfileInvalid) ||
		errors.Is(err, clientcontrol.ErrTransportProfileIncompatible) {
		return clientcontrol.PlatformTunnelStartupStageProfileValidate,
			clientcontrol.PlatformTunnelPrerequisiteTransportProfile
	}
	return clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
		clientcontrol.PlatformTunnelPrerequisiteHostImplementation
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
	if len(capability.SupportedUnderlayRoutePolicies) > 0 {
		clone.SupportedUnderlayRoutePolicies = append([]clientcontrol.PlatformTunnelUnderlayRoutePolicy(nil), capability.SupportedUnderlayRoutePolicies...)
	}
	if len(capability.ExecutionPlans) > 0 {
		clone.ExecutionPlans = append([]clientcontrol.RuntimeExecutionPlanDescriptor(nil), capability.ExecutionPlans...)
	}
	return clone
}

func supportsUnderlayRoutePolicy(
	capability clientcontrol.PlatformTunnelCapability,
	policy clientcontrol.PlatformTunnelUnderlayRoutePolicy,
) bool {
	if strings.TrimSpace(string(policy)) == "" ||
		policy == clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard {
		return true
	}
	for _, candidate := range capability.SupportedUnderlayRoutePolicies {
		if candidate == policy {
			return true
		}
	}
	return false
}

func newAndroidRouteExclusionError(message string) error {
	return &androidVPNServiceRoutePolicyError{
		prerequisite: clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
		message:      strings.TrimSpace(message),
	}
}

func NewAndroidRouteExclusionError(message string) error {
	return newAndroidRouteExclusionError(message)
}

func newAndroidDNSBypassError(message string) error {
	return &androidVPNServiceRoutePolicyError{
		prerequisite: clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
		message:      strings.TrimSpace(message),
	}
}

func NewAndroidDNSBypassError(message string) error {
	return newAndroidDNSBypassError(message)
}

func newAndroidAppRoutingPolicyError(message string) error {
	return &androidVPNServiceRoutePolicyError{
		prerequisite: clientcontrol.PlatformTunnelPrerequisiteAppRoutingPolicy,
		message:      strings.TrimSpace(message),
	}
}

func NewAndroidAppRoutingPolicyError(message string) error {
	return newAndroidAppRoutingPolicyError(message)
}

func newAndroidPermissionPendingError(message string) error {
	return &androidVPNServicePermissionPendingError{
		message: strings.TrimSpace(message),
	}
}

func NewAndroidPermissionPendingError(message string) error {
	return newAndroidPermissionPendingError(message)
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func supportedAndroidVPNServiceCapability(message string) clientcontrol.PlatformTunnelCapability {
	return clientcontrol.PlatformTunnelCapability{
		Mode:      clientcontrol.PlatformTunnelModeAndroidVPNService,
		Available: true,
		Message:   strings.TrimSpace(message),
		SatisfiedPrerequisites: []clientcontrol.PlatformTunnelPrerequisite{
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
		},
		SupportedUnderlayRoutePolicies: []clientcontrol.PlatformTunnelUnderlayRoutePolicy{
			clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard,
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		},
		ExecutionPlans: androidVPNServiceExecutionPlans(true, message),
	}
}
