package linuxdesktophost

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	"strings"
	"sync"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

type LinuxNativePolicyDirectives struct {
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy
	UnderlayExclusions  []string
	DNSBypassRequired   bool
}

type LinuxTunHelperStartup struct {
	Lease            clientcontrol.WireGuardTurnExecutionLease
	PolicyDirectives LinuxNativePolicyDirectives
}

type LinuxTunHelper interface {
	Start(context.Context, LinuxTunHelperStartup) error
	Cleanup(context.Context) error
}

type LinuxTunNativeStartRequest struct {
	AttemptID        string
	AttemptNonce     string
	Mode             clientcontrol.PlatformTunnelMode
	ExecutionPlan    clientcontrol.RuntimeExecutionPlan
	Lease            clientcontrol.WireGuardTurnExecutionLease
	PolicyDirectives LinuxNativePolicyDirectives
}

type LinuxTunNativeStartResult struct {
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy
	UnderlayExclusions  []string
	Dataplane           *clientcontrol.PlatformTunnelDataplaneEvidence
}

type LinuxTunNativeCleanupRequest struct {
	AttemptID    string
	AttemptNonce string
	Mode         clientcontrol.PlatformTunnelMode
}

type LinuxTunNativeClient interface {
	Start(context.Context, LinuxTunNativeStartRequest) (LinuxTunNativeStartResult, error)
	Cleanup(context.Context, LinuxTunNativeCleanupRequest) error
}

type LinuxTunNativeFailureKind string

const (
	LinuxTunNativeFailurePermissionDenied LinuxTunNativeFailureKind = "permission_denied"
	LinuxTunNativeFailureMalformedPayload LinuxTunNativeFailureKind = "malformed_payload"
	LinuxTunNativeFailureHelperExit       LinuxTunNativeFailureKind = "helper_exit"
	LinuxTunNativeFailureNativeStart      LinuxTunNativeFailureKind = "native_start"
	LinuxTunNativeFailureRouteValidate    LinuxTunNativeFailureKind = "route_validate"
	LinuxTunNativeFailureRuntimeAttach    LinuxTunNativeFailureKind = "runtime_attach"
	LinuxTunNativeFailureDataplane        LinuxTunNativeFailureKind = "dataplane"
	LinuxTunNativeFailureCleanup          LinuxTunNativeFailureKind = "cleanup"
	LinuxTunNativeFailureStaleState       LinuxTunNativeFailureKind = "stale_native_state"
)

type LinuxTunNativeFailure struct {
	Kind         LinuxTunNativeFailureKind
	Message      string
	Stage        clientcontrol.PlatformTunnelStartupStage
	Prerequisite clientcontrol.PlatformTunnelPrerequisite
}

func (e *LinuxTunNativeFailure) Error() string {
	if e == nil {
		return ""
	}
	return strings.TrimSpace(e.Message)
}

type LinuxTunLifecycle interface {
	AcquirePermission(context.Context, clientcontrol.PlatformTunnelStartRequest) error
	ValidateRoutePolicy(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease) (*linuxRoutePolicyState, error)
	BringupHost(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease, *linuxRoutePolicyState) error
	AttachRuntime(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease, *linuxRoutePolicyState) error
	VerifyDataplane(context.Context, clientcontrol.PlatformTunnelStartRequest, *clientcontrol.RuntimeExecutionPlan, *clientcontrol.WireGuardTurnExecutionLease, *linuxRoutePolicyState) (*clientcontrol.PlatformTunnelDataplaneEvidence, error)
	Cleanup(context.Context) error
}

type linuxTunLeaseProvider func(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.WireGuardTurnExecutionLease, error)

type linuxRoutePolicyState struct {
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy
	Exclusions          []string
}

type linuxTunRoutePolicyError struct {
	prerequisite clientcontrol.PlatformTunnelPrerequisite
	message      string
}

func (e *linuxTunRoutePolicyError) Error() string {
	if e == nil {
		return ""
	}
	if strings.TrimSpace(e.message) != "" {
		return e.message
	}
	return fmt.Sprintf("linux_tun route policy requires %s", e.prerequisite)
}

type linuxTunPrerequisiteFailure struct {
	prerequisite clientcontrol.PlatformTunnelPrerequisite
	message      string
}

func (e *linuxTunPrerequisiteFailure) Error() string {
	if e == nil {
		return ""
	}
	return strings.TrimSpace(e.message)
}

var (
	linuxTunPrerequisiteCheck   = defaultLinuxTunPrerequisiteCheck
	newLinuxTunLifecycleForHost = newLinuxTunLifecycle
)

const (
	linuxTunPackagedTargetEnv    = "VKTP_LINUX_PACKAGED_TARGET"
	linuxTunPackagedTargetUbuntu = "ubuntu"
)

type linuxTunController struct {
	capability clientcontrol.PlatformTunnelCapability
	native     LinuxTunNativeClient

	mu            sync.Mutex
	leaseFn       linuxTunLeaseProvider
	attemptMu     sync.Mutex
	attemptSeq    uint64
	activeAttempt linuxTunNativeAttempt
}

func newLinuxTunController(
	capability clientcontrol.PlatformTunnelCapability,
	lifecycle LinuxTunLifecycle,
) *linuxTunController {
	var native LinuxTunNativeClient
	if lifecycle != nil {
		native = linuxTunLifecycleNativeClient{lifecycle: lifecycle}
	}
	return newLinuxTunControllerWithNativeClient(capability, native)
}

func newLinuxTunControllerWithNativeClient(
	capability clientcontrol.PlatformTunnelCapability,
	native LinuxTunNativeClient,
) *linuxTunController {
	normalized := capability
	if normalized.Mode == "" {
		normalized.Mode = clientcontrol.PlatformTunnelModeLinuxTun
	}
	if len(normalized.ExecutionPlans) == 0 {
		normalized.ExecutionPlans = []clientcontrol.RuntimeExecutionPlanDescriptor{{
			Plan: clientcontrol.RuntimeExecutionPlan{
				AccessMethod:  clientcontrol.RuntimeAccessMethodTURNCredentials,
				CarrierFamily: clientcontrol.RuntimeCarrierFamilyTURNDatagram,
				EngineFamily:  clientcontrol.RuntimeEngineFamilyWireGuardNative,
				HostAdapter:   clientcontrol.RuntimeHostAdapterLinuxTun,
			},
			SupportState:         supportStateForCapability(normalized.Available),
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   clientcontrol.RuntimeRemoteEndpointRoleWireGuardRawDatagram,
			Default:              true,
			Message:              strings.TrimSpace(normalized.Message),
		}}
	}
	return &linuxTunController{
		capability: normalized,
		native:     native,
	}
}

func currentLinuxTunCapability(build clientcontrol.BuildIdentity) clientcontrol.PlatformTunnelCapability {
	if failure := linuxTunPrerequisiteCheck(build); failure != nil {
		prerequisite := failure.prerequisite
		if strings.TrimSpace(string(prerequisite)) == "" {
			prerequisite = clientcontrol.PlatformTunnelPrerequisiteHostImplementation
		}
		return clientcontrol.PlatformTunnelCapability{
			Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
			Available:           false,
			MissingPrerequisite: prerequisite,
			Message:             failure.Error(),
		}
	}
	return supportedLinuxTunCapability("packaged Ubuntu Linux host can negotiate linux_tun; privilege is acquired during tunnel startup")
}

func unavailableLinuxTunCapability(
	build clientcontrol.BuildIdentity,
	prerequisite clientcontrol.PlatformTunnelPrerequisite,
	message string,
) clientcontrol.PlatformTunnelCapability {
	if strings.TrimSpace(string(prerequisite)) == "" {
		prerequisite = clientcontrol.PlatformTunnelPrerequisiteHostImplementation
	}
	if strings.TrimSpace(message) == "" {
		message = fmt.Sprintf(
			"The %s host reserves mode %s for the dedicated packaged Linux desktop host boundary, but the ready path is not implemented yet.",
			hostTargetLabel(build),
			clientcontrol.PlatformTunnelModeLinuxTun,
		)
	}
	return clientcontrol.PlatformTunnelCapability{
		Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
		Available:           false,
		MissingPrerequisite: prerequisite,
		Message:             strings.TrimSpace(message),
	}
}

func supportedLinuxTunCapability(message string) clientcontrol.PlatformTunnelCapability {
	return clientcontrol.PlatformTunnelCapability{
		Mode:      clientcontrol.PlatformTunnelModeLinuxTun,
		Available: true,
		SatisfiedPrerequisites: []clientcontrol.PlatformTunnelPrerequisite{
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

func hostTargetLabel(build clientcontrol.BuildIdentity) string {
	if target := strings.TrimSpace(build.Target); target != "" {
		return target
	}
	return "linux"
}

func (c *linuxTunController) Capability() clientcontrol.PlatformTunnelCapability {
	if c == nil {
		return clientcontrol.PlatformTunnelCapability{}
	}
	return clonePlatformTunnelCapability(c.capability)
}

func (c *linuxTunController) Start(
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
			fmt.Sprintf("linux desktop host does not publish platform tunnel mode %s", req.Mode),
		), nil
	}
	selectedPlan, err := selectLinuxExecutionPlan(capability.ExecutionPlans, req.ExecutionPlan)
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
	if c.native == nil {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			"linux desktop host reports linux_tun support without a packaged lifecycle implementation",
		), nil
	}
	if !supportsLinuxUnderlayRoutePolicy(capability, req.UnderlayRoutePolicy) {
		return capabilityCheckFailure(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			req.UnderlayRoutePolicy,
			fmt.Sprintf(
				"linux desktop host does not advertise underlay_route_policy %s for mode %s",
				req.UnderlayRoutePolicy,
				req.Mode,
			),
		), nil
	}
	leaseFn := c.wireGuardTurnLeaseProvider()
	if leaseFn == nil {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			"linux desktop host cannot materialize the strict TURN datagram WireGuard runtime lease",
		)
	}
	lease, err := leaseFn(ctx, req, selectedPlan)
	if err != nil {
		stage, prerequisite := leaseMaterializationFailureClassification(err)
		return startFailureResult(
			req.Mode,
			selectedPlan,
			stage,
			prerequisite,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	attempt, ok := c.beginNativeAttempt()
	if !ok {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageCapabilityCheck,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			req.UnderlayRoutePolicy,
			"linux_tun native startup already has an active attempt",
		)
	}
	nativeResult, err := c.native.Start(ctx, LinuxTunNativeStartRequest{
		AttemptID:     attempt.id,
		AttemptNonce:  attempt.nonce,
		Mode:          req.Mode,
		ExecutionPlan: *selectedPlan,
		Lease:         cloneLinuxTunNativeLease(lease),
		PolicyDirectives: LinuxNativePolicyDirectives{
			UnderlayRoutePolicy: req.UnderlayRoutePolicy,
			UnderlayExclusions:  helperUnderlayExclusions(lease),
			DNSBypassRequired:   true,
		},
	})
	if err != nil {
		stage, prerequisite := nativeStartFailureClassification(err)
		if !linuxTunStartupStageNeedsCleanup(stage) {
			c.endNativeAttempt(attempt.id)
		}
		return startFailureResult(
			req.Mode,
			selectedPlan,
			stage,
			prerequisite,
			req.UnderlayRoutePolicy,
			err.Error(),
		)
	}
	underlayRoutePolicy := nativeResult.UnderlayRoutePolicy
	if strings.TrimSpace(string(underlayRoutePolicy)) == "" {
		underlayRoutePolicy = req.UnderlayRoutePolicy
	}
	dataplane := nativeResult.Dataplane
	if dataplane == nil ||
		!dataplane.HostAttached ||
		!dataplane.WireGuardHandshakeFresh ||
		!dataplane.BidirectionalTrafficVerified {
		return startFailureResult(
			req.Mode,
			selectedPlan,
			clientcontrol.PlatformTunnelStartupStageDataplaneVerify,
			clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence,
			req.UnderlayRoutePolicy,
			"linux_tun dataplane verification did not produce fresh WireGuard handshake and bidirectional traffic evidence",
		)
	}
	return clientcontrol.PlatformTunnelStartResult{
		Mode:                    req.Mode,
		ExecutionPlan:           cloneRuntimeExecutionPlan(selectedPlan),
		RemoteIngress:           clientcontrol.RemoteIngressDiagnosticsFromWireGuardTurnLease(lease),
		Dataplane:               dataplane,
		Ready:                   true,
		Stage:                   clientcontrol.PlatformTunnelStartupStageDataplaneVerify,
		UnderlayRoutePolicy:     underlayRoutePolicy,
		UnderlayRouteExclusions: append([]string(nil), nativeResult.UnderlayExclusions...),
	}, nil
}

func (c *linuxTunController) Stop(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStopRequest,
) (clientcontrol.PlatformTunnelStopResult, error) {
	capability := c.Capability()
	if req.Mode != capability.Mode {
		return clientcontrol.PlatformTunnelStopResult{}, fmt.Errorf(
			"linux desktop host does not publish platform tunnel mode %s",
			req.Mode,
		)
	}
	if c.native == nil {
		return clientcontrol.PlatformTunnelStopResult{}, fmt.Errorf(
			"linux desktop host does not implement stop for %s",
			req.Mode,
		)
	}
	attempt := c.activeNativeAttempt()
	if err := c.native.Cleanup(ctx, LinuxTunNativeCleanupRequest{
		AttemptID:    attempt.id,
		AttemptNonce: attempt.nonce,
		Mode:         req.Mode,
	}); err != nil {
		return clientcontrol.PlatformTunnelStopResult{}, err
	}
	c.endNativeAttempt(attempt.id)
	return clientcontrol.PlatformTunnelStopResult{
		Mode:    req.Mode,
		Stopped: true,
		Message: "Linux TUN disconnected.",
	}, nil
}

func (c *linuxTunController) setWireGuardTurnLeaseProvider(fn linuxTunLeaseProvider) {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.leaseFn = fn
}

func (c *linuxTunController) wireGuardTurnLeaseProvider() linuxTunLeaseProvider {
	if c == nil {
		return nil
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	return c.leaseFn
}

func helperUnderlayExclusions(lease *clientcontrol.WireGuardTurnExecutionLease) []string {
	if lease == nil {
		return nil
	}
	endpoint := strings.TrimSpace(lease.TURNServerAddress)
	if endpoint == "" {
		return nil
	}
	return []string{endpoint}
}

type linuxTunNativeAttempt struct {
	id    string
	nonce string
}

func (c *linuxTunController) beginNativeAttempt() (linuxTunNativeAttempt, bool) {
	if c == nil {
		return linuxTunNativeAttempt{}, false
	}
	c.attemptMu.Lock()
	defer c.attemptMu.Unlock()
	if strings.TrimSpace(c.activeAttempt.id) != "" {
		return linuxTunNativeAttempt{}, false
	}
	c.attemptSeq++
	attempt := linuxTunNativeAttempt{
		id:    fmt.Sprintf("linux-tun-%d", c.attemptSeq),
		nonce: randomLinuxTunAttemptNonce(c.attemptSeq),
	}
	c.activeAttempt = attempt
	return attempt, true
}

func (c *linuxTunController) activeNativeAttempt() linuxTunNativeAttempt {
	if c == nil {
		return linuxTunNativeAttempt{}
	}
	c.attemptMu.Lock()
	defer c.attemptMu.Unlock()
	return c.activeAttempt
}

func (c *linuxTunController) endNativeAttempt(attemptID string) {
	if c == nil || strings.TrimSpace(attemptID) == "" {
		return
	}
	c.attemptMu.Lock()
	defer c.attemptMu.Unlock()
	if c.activeAttempt.id == attemptID {
		c.activeAttempt = linuxTunNativeAttempt{}
	}
}

func randomLinuxTunAttemptNonce(seq uint64) string {
	var buf [16]byte
	if _, err := rand.Read(buf[:]); err == nil {
		return hex.EncodeToString(buf[:])
	}
	return fmt.Sprintf("linux-tun-nonce-%d", seq)
}

type linuxTunLifecycleNativeClient struct {
	lifecycle LinuxTunLifecycle
}

func (c linuxTunLifecycleNativeClient) Start(
	ctx context.Context,
	req LinuxTunNativeStartRequest,
) (LinuxTunNativeStartResult, error) {
	if c.lifecycle == nil {
		return LinuxTunNativeStartResult{}, &linuxTunNativeStartError{
			stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message:      "linux_tun native lifecycle is not configured",
		}
	}
	startReq := clientcontrol.PlatformTunnelStartRequest{
		Mode:                req.Mode,
		UnderlayRoutePolicy: req.PolicyDirectives.UnderlayRoutePolicy,
	}
	plan := req.ExecutionPlan
	lease := req.Lease
	if err := c.lifecycle.AcquirePermission(ctx, startReq); err != nil {
		return LinuxTunNativeStartResult{}, &linuxTunNativeStartError{
			stage:        clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			prerequisite: clientcontrol.PlatformTunnelPrerequisitePermission,
			message:      err.Error(),
		}
	}
	routeState, err := c.lifecycle.ValidateRoutePolicy(ctx, startReq, &plan, &lease)
	if err != nil {
		return LinuxTunNativeStartResult{}, &linuxTunNativeStartError{
			stage:        clientcontrol.PlatformTunnelStartupStageRouteValidate,
			prerequisite: routePolicyPrerequisite(err),
			message:      err.Error(),
		}
	}
	if err := c.lifecycle.BringupHost(ctx, startReq, &plan, &lease, routeState); err != nil {
		return LinuxTunNativeStartResult{}, &linuxTunNativeStartError{
			stage:        clientcontrol.PlatformTunnelStartupStageHostBringup,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message:      err.Error(),
		}
	}
	if err := c.lifecycle.AttachRuntime(ctx, startReq, &plan, &lease, routeState); err != nil {
		return LinuxTunNativeStartResult{}, &linuxTunNativeStartError{
			stage:        clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			message:      err.Error(),
		}
	}
	dataplane, err := c.lifecycle.VerifyDataplane(ctx, startReq, &plan, &lease, routeState)
	if err != nil {
		return LinuxTunNativeStartResult{}, &linuxTunNativeStartError{
			stage:        clientcontrol.PlatformTunnelStartupStageDataplaneVerify,
			prerequisite: clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence,
			message:      err.Error(),
		}
	}
	result := LinuxTunNativeStartResult{
		UnderlayRoutePolicy: req.PolicyDirectives.UnderlayRoutePolicy,
		Dataplane:           dataplane,
	}
	if routeState != nil {
		result.UnderlayRoutePolicy = routeState.UnderlayRoutePolicy
		result.UnderlayExclusions = append([]string(nil), routeState.Exclusions...)
	}
	return result, nil
}

func (c linuxTunLifecycleNativeClient) Cleanup(ctx context.Context, _ LinuxTunNativeCleanupRequest) error {
	if c.lifecycle == nil {
		return nil
	}
	return c.lifecycle.Cleanup(ctx)
}

type linuxTunNativeStartError struct {
	stage        clientcontrol.PlatformTunnelStartupStage
	prerequisite clientcontrol.PlatformTunnelPrerequisite
	message      string
}

func (e *linuxTunNativeStartError) Error() string {
	if e == nil {
		return ""
	}
	return strings.TrimSpace(e.message)
}

func nativeStartFailureClassification(err error) (clientcontrol.PlatformTunnelStartupStage, clientcontrol.PlatformTunnelPrerequisite) {
	var nativeFailure *LinuxTunNativeFailure
	if errors.As(err, &nativeFailure) {
		if strings.TrimSpace(string(nativeFailure.Stage)) != "" ||
			strings.TrimSpace(string(nativeFailure.Prerequisite)) != "" {
			stage := nativeFailure.Stage
			if strings.TrimSpace(string(stage)) == "" {
				stage = clientcontrol.PlatformTunnelStartupStageHostBringup
			}
			prerequisite := nativeFailure.Prerequisite
			if strings.TrimSpace(string(prerequisite)) == "" {
				prerequisite = clientcontrol.PlatformTunnelPrerequisiteHostImplementation
			}
			return stage, prerequisite
		}
		return nativeFailureKindClassification(nativeFailure.Kind)
	}
	var nativeErr *linuxTunNativeStartError
	if errors.As(err, &nativeErr) {
		stage := nativeErr.stage
		if strings.TrimSpace(string(stage)) == "" {
			stage = clientcontrol.PlatformTunnelStartupStageHostBringup
		}
		prerequisite := nativeErr.prerequisite
		if strings.TrimSpace(string(prerequisite)) == "" {
			prerequisite = clientcontrol.PlatformTunnelPrerequisiteHostImplementation
		}
		return stage, prerequisite
	}
	return clientcontrol.PlatformTunnelStartupStageHostBringup,
		clientcontrol.PlatformTunnelPrerequisiteHostImplementation
}

func nativeFailureKindClassification(kind LinuxTunNativeFailureKind) (clientcontrol.PlatformTunnelStartupStage, clientcontrol.PlatformTunnelPrerequisite) {
	switch kind {
	case LinuxTunNativeFailurePermissionDenied:
		return clientcontrol.PlatformTunnelStartupStagePermissionAcquire,
			clientcontrol.PlatformTunnelPrerequisitePermission
	case LinuxTunNativeFailureRouteValidate:
		return clientcontrol.PlatformTunnelStartupStageRouteValidate,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion
	case LinuxTunNativeFailureRuntimeAttach:
		return clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation
	case LinuxTunNativeFailureDataplane:
		return clientcontrol.PlatformTunnelStartupStageDataplaneVerify,
			clientcontrol.PlatformTunnelPrerequisiteDataplaneEvidence
	case LinuxTunNativeFailureMalformedPayload,
		LinuxTunNativeFailureHelperExit,
		LinuxTunNativeFailureNativeStart,
		LinuxTunNativeFailureStaleState,
		LinuxTunNativeFailureCleanup:
		return clientcontrol.PlatformTunnelStartupStageHostBringup,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation
	default:
		return clientcontrol.PlatformTunnelStartupStageHostBringup,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation
	}
}

func linuxTunStartupStageNeedsCleanup(stage clientcontrol.PlatformTunnelStartupStage) bool {
	switch stage {
	case clientcontrol.PlatformTunnelStartupStageRouteValidate,
		clientcontrol.PlatformTunnelStartupStageHostBringup,
		clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
		clientcontrol.PlatformTunnelStartupStageDataplaneVerify:
		return true
	default:
		return false
	}
}

func cloneLinuxTunNativeLease(lease *clientcontrol.WireGuardTurnExecutionLease) clientcontrol.WireGuardTurnExecutionLease {
	if lease == nil {
		return clientcontrol.WireGuardTurnExecutionLease{}
	}
	clone := *lease
	clone.ResolutionID = ""
	if len(lease.ClientAddresses) > 0 {
		clone.ClientAddresses = append([]string(nil), lease.ClientAddresses...)
	}
	if len(lease.AllowedIPs) > 0 {
		clone.AllowedIPs = append([]string(nil), lease.AllowedIPs...)
	}
	if len(lease.DNSServers) > 0 {
		clone.DNSServers = append([]string(nil), lease.DNSServers...)
	}
	if lease.ExpiresAt != nil {
		expiresAt := lease.ExpiresAt.UTC()
		clone.ExpiresAt = &expiresAt
	}
	return clone
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

func cloneRuntimeExecutionPlan(plan *clientcontrol.RuntimeExecutionPlan) *clientcontrol.RuntimeExecutionPlan {
	if plan == nil {
		return nil
	}
	copy := *plan
	return &copy
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

func routePolicyPrerequisite(err error) clientcontrol.PlatformTunnelPrerequisite {
	var routeErr *linuxTunRoutePolicyError
	if errors.As(err, &routeErr) && strings.TrimSpace(string(routeErr.prerequisite)) != "" {
		return routeErr.prerequisite
	}
	return clientcontrol.PlatformTunnelPrerequisiteRouteExclusion
}

func selectLinuxExecutionPlan(
	descriptors []clientcontrol.RuntimeExecutionPlanDescriptor,
	requested *clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.RuntimeExecutionPlan, error) {
	if len(descriptors) == 0 {
		if requested == nil {
			return nil, fmt.Errorf("linux_tun does not advertise any execution plans")
		}
		return nil, fmt.Errorf("requested linux_tun execution plan is not advertised by this host")
	}
	if requested != nil {
		for _, descriptor := range descriptors {
			if runtimeExecutionPlanEquals(descriptor.Plan, *requested) {
				return cloneRuntimeExecutionPlan(&descriptor.Plan), nil
			}
		}
		return nil, fmt.Errorf("requested linux_tun execution plan is not advertised by this host")
	}
	for _, descriptor := range descriptors {
		if descriptor.Default {
			return cloneRuntimeExecutionPlan(&descriptor.Plan), nil
		}
	}
	if len(descriptors) == 1 {
		return cloneRuntimeExecutionPlan(&descriptors[0].Plan), nil
	}
	return nil, fmt.Errorf("linux_tun startup requires an explicit execution plan selection")
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

func supportsLinuxUnderlayRoutePolicy(
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
