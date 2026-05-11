package linuxdesktophost

import (
	"context"
	"errors"
	"fmt"
	"strings"

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

type linuxTunLeaseProvider func(
	context.Context,
	clientcontrol.PlatformTunnelStartRequest,
	*clientcontrol.RuntimeExecutionPlan,
) (*clientcontrol.WireGuardTurnExecutionLease, error)

type linuxTunHelperError struct {
	stage           clientcontrol.PlatformTunnelStartupStage
	prerequisite    clientcontrol.PlatformTunnelPrerequisite
	message         string
	cleanupRequired bool
}

func (e *linuxTunHelperError) Error() string {
	if e == nil {
		return ""
	}
	if strings.TrimSpace(e.message) != "" {
		return e.message
	}
	return "linux_tun helper startup failed"
}

type linuxTunController struct {
	capability clientcontrol.PlatformTunnelCapability
	helper     LinuxTunHelper
	leaseFn    linuxTunLeaseProvider
}

func newLinuxTunController(
	capability clientcontrol.PlatformTunnelCapability,
	helper LinuxTunHelper,
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
		helper:     helper,
	}
}

func currentLinuxTunCapability(build clientcontrol.BuildIdentity) clientcontrol.PlatformTunnelCapability {
	return clientcontrol.PlatformTunnelCapability{
		Mode:                clientcontrol.PlatformTunnelModeLinuxTun,
		Available:           false,
		MissingPrerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		Message: fmt.Sprintf(
			"The %s host reserves mode %s for the dedicated packaged Linux desktop host boundary, but the ready path is not implemented yet.",
			hostTargetLabel(build),
			clientcontrol.PlatformTunnelModeLinuxTun,
		),
	}
}

func supportedLinuxTunCapability(message string) clientcontrol.PlatformTunnelCapability {
	return clientcontrol.PlatformTunnelCapability{
		Mode:      clientcontrol.PlatformTunnelModeLinuxTun,
		Available: true,
		SatisfiedPrerequisites: []clientcontrol.PlatformTunnelPrerequisite{
			clientcontrol.PlatformTunnelPrerequisitePermission,
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
	capability := c.capability
	if len(capability.ExecutionPlans) > 0 {
		capability.ExecutionPlans = append([]clientcontrol.RuntimeExecutionPlanDescriptor(nil), capability.ExecutionPlans...)
	}
	if len(capability.SatisfiedPrerequisites) > 0 {
		capability.SatisfiedPrerequisites = append([]clientcontrol.PlatformTunnelPrerequisite(nil), capability.SatisfiedPrerequisites...)
	}
	if len(capability.SupportedUnderlayRoutePolicies) > 0 {
		capability.SupportedUnderlayRoutePolicies = append([]clientcontrol.PlatformTunnelUnderlayRoutePolicy(nil), capability.SupportedUnderlayRoutePolicies...)
	}
	return capability
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
		return clientcontrol.PlatformTunnelStartResult{
			Mode:                req.Mode,
			Ready:               false,
			Stage:               clientcontrol.PlatformTunnelStartupStageCapabilityCheck,
			MissingPrerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			UnderlayRoutePolicy: req.UnderlayRoutePolicy,
			Message:             fmt.Sprintf("linux desktop host does not publish platform tunnel mode %s", req.Mode),
		}, nil
	}
	if len(capability.ExecutionPlans) > 0 {
		plan := capability.ExecutionPlans[0].Plan
		if !capability.Available {
			return clientcontrol.PlatformTunnelStartResult{
				Mode:                req.Mode,
				ExecutionPlan:       &plan,
				Ready:               false,
				Stage:               clientcontrol.PlatformTunnelStartupStageCapabilityCheck,
				MissingPrerequisite: capability.MissingPrerequisite,
				UnderlayRoutePolicy: req.UnderlayRoutePolicy,
				Message:             capability.Message,
			}, nil
		}
		if c.helper == nil {
			return startFailureResult(
				req.Mode,
				&plan,
				clientcontrol.PlatformTunnelStartupStageHostBringup,
				clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
				req.UnderlayRoutePolicy,
				"linux desktop host reports linux_tun support without a packaged helper implementation",
			)
		}
		leaseFn := c.wireGuardTurnLeaseProvider()
		if leaseFn == nil {
			return startFailureResult(
				req.Mode,
				&plan,
				clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
				clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
				req.UnderlayRoutePolicy,
				"linux desktop host cannot materialize the strict TURN datagram WireGuard runtime lease",
			)
		}
		lease, err := leaseFn(ctx, req, &plan)
		if err != nil {
			stage, prerequisite := leaseMaterializationFailureClassification(err)
			return startFailureResult(
				req.Mode,
				&plan,
				stage,
				prerequisite,
				req.UnderlayRoutePolicy,
				err.Error(),
			)
		}
		startup := LinuxTunHelperStartup{
			Lease: *lease,
			PolicyDirectives: LinuxNativePolicyDirectives{
				UnderlayRoutePolicy: req.UnderlayRoutePolicy,
				UnderlayExclusions:  helperUnderlayExclusions(lease),
				DNSBypassRequired:   true,
			},
		}
		if err := c.helper.Start(ctx, startup); err != nil {
			return c.startFailureForHelperError(ctx, req, &plan, err)
		}
		if err := c.helper.Cleanup(ctx); err != nil {
			return startFailureResult(
				req.Mode,
				&plan,
				clientcontrol.PlatformTunnelStartupStageHostBringup,
				clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
				req.UnderlayRoutePolicy,
				fmt.Sprintf("linux_tun helper cleanup failed after reserved startup boundary completed: %v", err),
			)
		}
		return clientcontrol.PlatformTunnelStartResult{
			Mode:                req.Mode,
			ExecutionPlan:       &plan,
			Ready:               false,
			Stage:               clientcontrol.PlatformTunnelStartupStageRuntimeAttach,
			MissingPrerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			UnderlayRoutePolicy: req.UnderlayRoutePolicy,
			Message:             "linux desktop host boundary is defined, but the packaged linux_tun ready path is not implemented yet",
		}, nil
	}
	return clientcontrol.PlatformTunnelStartResult{
		Mode:                req.Mode,
		Ready:               false,
		Stage:               clientcontrol.PlatformTunnelStartupStageCapabilityCheck,
		MissingPrerequisite: capability.MissingPrerequisite,
		UnderlayRoutePolicy: req.UnderlayRoutePolicy,
		Message:             capability.Message,
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
	if c.helper == nil {
		return clientcontrol.PlatformTunnelStopResult{}, fmt.Errorf(
			"linux desktop host does not implement stop for %s",
			req.Mode,
		)
	}
	if err := c.helper.Cleanup(ctx); err != nil {
		return clientcontrol.PlatformTunnelStopResult{}, err
	}
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
	c.leaseFn = fn
}

func (c *linuxTunController) wireGuardTurnLeaseProvider() linuxTunLeaseProvider {
	if c == nil {
		return nil
	}
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

func (c *linuxTunController) startFailureForHelperError(
	ctx context.Context,
	req clientcontrol.PlatformTunnelStartRequest,
	plan *clientcontrol.RuntimeExecutionPlan,
	err error,
) (clientcontrol.PlatformTunnelStartResult, error) {
	stage := clientcontrol.PlatformTunnelStartupStageHostBringup
	prerequisite := clientcontrol.PlatformTunnelPrerequisiteHostImplementation
	message := err.Error()
	cleanupRequired := false
	var helperErr *linuxTunHelperError
	if errors.As(err, &helperErr) && helperErr != nil {
		if strings.TrimSpace(string(helperErr.stage)) != "" {
			stage = helperErr.stage
		}
		if strings.TrimSpace(string(helperErr.prerequisite)) != "" {
			prerequisite = helperErr.prerequisite
		}
		if strings.TrimSpace(helperErr.message) != "" {
			message = helperErr.message
		}
		cleanupRequired = helperErr.cleanupRequired
	}
	if cleanupRequired && c.helper != nil {
		if cleanupErr := c.helper.Cleanup(ctx); cleanupErr != nil {
			message = fmt.Sprintf("%s; cleanup failed: %v", message, cleanupErr)
		}
	}
	return startFailureResult(
		req.Mode,
		plan,
		stage,
		prerequisite,
		req.UnderlayRoutePolicy,
		message,
	)
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
