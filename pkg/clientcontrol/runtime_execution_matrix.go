package clientcontrol

import (
	"errors"
	"fmt"
	"strings"
)

const (
	CapabilityRuntimeExecutionExperimentalWebRTCDataChannel Capability = "runtime_execution_experimental_webrtc_datachannel"
	CapabilityRuntimeExecutionForeignCore                   Capability = "runtime_execution_foreign_core"
)

var (
	errRuntimeExecutionPlanSelectionRequired = errors.New("runtime execution plan selection is required")
	errRuntimeExecutionPlanUnsupported       = errors.New("requested runtime execution plan is unsupported")
	errRuntimeExecutionPlanUnavailable       = errors.New("requested runtime execution plan is unavailable")
)

func resolutionArtifactAccessMethods(family ArtifactFamily) []RuntimeAccessMethod {
	switch family {
	case ArtifactFamilyGenericTURN:
		return []RuntimeAccessMethod{RuntimeAccessMethodTURNCredentials}
	default:
		return nil
	}
}

func resolutionExecutionPlansForAction(
	action ArtifactAction,
	family ArtifactFamily,
	platformTunnels []PlatformTunnelCapability,
) []RuntimeExecutionPlanDescriptor {
	if action != ArtifactActionStartOnThisDevice || family != ArtifactFamilyGenericTURN {
		return nil
	}

	plans := []RuntimeExecutionPlanDescriptor{
		{
			Plan: RuntimeExecutionPlan{
				AccessMethod:  RuntimeAccessMethodTURNCredentials,
				CarrierFamily: RuntimeCarrierFamilyTURNDTLSOverlay,
				EngineFamily:  RuntimeEngineFamilyCustomPacketOverlay,
			},
			SupportState:         RuntimeExecutionPlanSupportStateSupported,
			RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
			Default:              true,
		},
	}
	for _, capability := range platformTunnels {
		plans = append(plans, cloneRuntimeExecutionPlanDescriptors(capability.ExecutionPlans)...)
	}
	return plans
}

func defaultRuntimeExecutionPlansForPlatformTunnel(capability PlatformTunnelCapability) []RuntimeExecutionPlanDescriptor {
	hostAdapter := runtimeHostAdapterForPlatformTunnelMode(capability.Mode)
	if hostAdapter == "" {
		return nil
	}

	supportState := RuntimeExecutionPlanSupportStateUnavailable
	if capability.Available {
		supportState = RuntimeExecutionPlanSupportStateSupported
	}

	return []RuntimeExecutionPlanDescriptor{{
		Plan: RuntimeExecutionPlan{
			AccessMethod:  RuntimeAccessMethodTURNCredentials,
			CarrierFamily: RuntimeCarrierFamilyTURNDatagram,
			EngineFamily:  RuntimeEngineFamilyWireGuardNative,
			HostAdapter:   hostAdapter,
		},
		SupportState:                  supportState,
		RemoteEndpointFamily:          RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:            RuntimeRemoteEndpointRoleWireGuardRawDatagram,
		Default:                       true,
		RequiredTransportProfileKinds: []TransportProfileKind{TransportProfileKindWireGuardNativeV1},
		Message:                       strings.TrimSpace(capability.Message),
	}}
}

func runtimeHostAdapterForPlatformTunnelMode(mode PlatformTunnelMode) RuntimeHostAdapter {
	switch mode {
	case PlatformTunnelModeAndroidVPNService:
		return RuntimeHostAdapterAndroidVPNService
	case PlatformTunnelModeAppleNetworkExtension:
		return RuntimeHostAdapterAppleNetworkExtension
	case PlatformTunnelModeWindowsWintun:
		return RuntimeHostAdapterWindowsWintun
	case PlatformTunnelModeLinuxTun:
		return RuntimeHostAdapterLinuxTun
	default:
		return ""
	}
}

func validateRuntimeExecutionPlan(plan RuntimeExecutionPlan) error {
	if !isKnownRuntimeAccessMethod(plan.AccessMethod) {
		return fmt.Errorf("runtime execution plan access_method %q is unknown", plan.AccessMethod)
	}
	if !isKnownRuntimeCarrierFamily(plan.CarrierFamily) {
		return fmt.Errorf("runtime execution plan carrier_family %q is unknown", plan.CarrierFamily)
	}
	if !isKnownRuntimeEngineFamily(plan.EngineFamily) {
		return fmt.Errorf("runtime execution plan engine_family %q is unknown", plan.EngineFamily)
	}
	if strings.TrimSpace(string(plan.HostAdapter)) != "" && !isKnownRuntimeHostAdapter(plan.HostAdapter) {
		return fmt.Errorf("runtime execution plan host_adapter %q is unknown", plan.HostAdapter)
	}
	return nil
}

func validateRuntimeExecutionPlanDescriptor(descriptor RuntimeExecutionPlanDescriptor) error {
	if err := validateRuntimeExecutionPlan(descriptor.Plan); err != nil {
		return err
	}
	if !isKnownRuntimeExecutionPlanSupportState(descriptor.SupportState) {
		return fmt.Errorf("runtime execution plan support_state %q is unknown", descriptor.SupportState)
	}
	if !isKnownRuntimeRemoteEndpointFamily(descriptor.RemoteEndpointFamily) {
		return fmt.Errorf("runtime execution plan remote_endpoint_family %q is unknown", descriptor.RemoteEndpointFamily)
	}
	if descriptor.Plan.AccessMethod == RuntimeAccessMethodTURNCredentials {
		if !isKnownRuntimeRemoteEndpointRole(descriptor.RemoteEndpointRole) {
			return fmt.Errorf("runtime execution plan remote_endpoint_role %q is unknown", descriptor.RemoteEndpointRole)
		}
	} else if strings.TrimSpace(string(descriptor.RemoteEndpointRole)) != "" &&
		!isKnownRuntimeRemoteEndpointRole(descriptor.RemoteEndpointRole) {
		return fmt.Errorf("runtime execution plan remote_endpoint_role %q is unknown", descriptor.RemoteEndpointRole)
	}
	for _, kind := range descriptor.RequiredTransportProfileKinds {
		if !isKnownTransportProfileKind(kind) {
			return fmt.Errorf("runtime execution plan requires unknown transport profile kind %q", kind)
		}
	}

	switch {
	case descriptor.Plan.AccessMethod == RuntimeAccessMethodTURNCredentials &&
		descriptor.Plan.CarrierFamily == RuntimeCarrierFamilyTURNDTLSOverlay &&
		descriptor.Plan.EngineFamily == RuntimeEngineFamilyCustomPacketOverlay:
		if strings.TrimSpace(string(descriptor.Plan.HostAdapter)) != "" {
			return fmt.Errorf("custom packet overlay runtime execution plan must not declare host_adapter %q", descriptor.Plan.HostAdapter)
		}
		if descriptor.RemoteEndpointFamily != RuntimeRemoteEndpointFamilyTURNServer {
			return fmt.Errorf("custom packet overlay runtime execution plan must use remote_endpoint_family %q", RuntimeRemoteEndpointFamilyTURNServer)
		}
		if descriptor.RemoteEndpointRole != RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay {
			return fmt.Errorf("custom packet overlay runtime execution plan must use remote_endpoint_role %q", RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay)
		}
		if descriptor.SupportState != RuntimeExecutionPlanSupportStateSupported {
			return fmt.Errorf("custom packet overlay runtime execution plan must be %q", RuntimeExecutionPlanSupportStateSupported)
		}
		return nil
	case descriptor.Plan.AccessMethod == RuntimeAccessMethodTURNCredentials &&
		descriptor.Plan.CarrierFamily == RuntimeCarrierFamilyTURNDatagram &&
		descriptor.Plan.EngineFamily == RuntimeEngineFamilyWireGuardNative:
		if !isKnownRuntimeHostAdapter(descriptor.Plan.HostAdapter) {
			return fmt.Errorf("wireguard_native runtime execution plan must declare a packaged host_adapter")
		}
		if descriptor.RemoteEndpointFamily != RuntimeRemoteEndpointFamilyTURNServer {
			return fmt.Errorf("wireguard_native runtime execution plan must use remote_endpoint_family %q", RuntimeRemoteEndpointFamilyTURNServer)
		}
		switch descriptor.RemoteEndpointRole {
		case RuntimeRemoteEndpointRoleWireGuardRawDatagram, RuntimeRemoteEndpointRoleUDPProtocolMultiplexer:
		default:
			return fmt.Errorf(
				"wireguard_native runtime execution plan remote_endpoint_role %q maps to protocol %q; expected remote_endpoint_role %q (protocol %q) or %q (protocol %q)",
				descriptor.RemoteEndpointRole,
				runtimeRemoteIngressProtocolForEndpointRole(descriptor.RemoteEndpointRole),
				RuntimeRemoteEndpointRoleWireGuardRawDatagram,
				RuntimeRemoteIngressProtocolRawWireGuard,
				RuntimeRemoteEndpointRoleUDPProtocolMultiplexer,
				RuntimeRemoteIngressProtocolUDPProtocolMux,
			)
		}
		switch descriptor.SupportState {
		case RuntimeExecutionPlanSupportStateSupported, RuntimeExecutionPlanSupportStateUnavailable:
			return nil
		default:
			return fmt.Errorf("wireguard_native runtime execution plan support_state %q is invalid", descriptor.SupportState)
		}
	case descriptor.Plan.AccessMethod == RuntimeAccessMethodWebRTCCallAttach &&
		descriptor.Plan.CarrierFamily == RuntimeCarrierFamilyWebRTCDataChannel:
		if descriptor.RequiresCapability != CapabilityRuntimeExecutionExperimentalWebRTCDataChannel {
			return fmt.Errorf("webrtc_datachannel runtime execution plan must require capability %q", CapabilityRuntimeExecutionExperimentalWebRTCDataChannel)
		}
		if descriptor.SupportState != RuntimeExecutionPlanSupportStateExperimental {
			return fmt.Errorf("webrtc_datachannel runtime execution plan must be %q", RuntimeExecutionPlanSupportStateExperimental)
		}
		if descriptor.RemoteEndpointFamily == RuntimeRemoteEndpointFamilyTURNServer {
			return fmt.Errorf("webrtc_datachannel runtime execution plan must not reuse remote_endpoint_family %q", RuntimeRemoteEndpointFamilyTURNServer)
		}
		return nil
	case descriptor.Plan.EngineFamily == RuntimeEngineFamilyProxyCoreAdapter ||
		descriptor.Plan.EngineFamily == RuntimeEngineFamilyTrustTunnelNative:
		if descriptor.RequiresCapability != CapabilityRuntimeExecutionForeignCore {
			return fmt.Errorf("foreign-core runtime execution plan must require capability %q", CapabilityRuntimeExecutionForeignCore)
		}
		if descriptor.SupportState == RuntimeExecutionPlanSupportStateSupported {
			return fmt.Errorf("foreign-core runtime execution plan cannot be %q without a future packaging slice", RuntimeExecutionPlanSupportStateSupported)
		}
		return nil
	default:
		return fmt.Errorf(
			"runtime execution plan %s/%s/%s/%s is not part of the documented compatibility matrix",
			descriptor.Plan.AccessMethod,
			descriptor.Plan.CarrierFamily,
			descriptor.Plan.EngineFamily,
			descriptor.Plan.HostAdapter,
		)
	}
}

func runtimeRemoteIngressProtocolForEndpointRole(role RuntimeRemoteEndpointRole) RuntimeRemoteIngressProtocol {
	switch role {
	case RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay:
		return RuntimeRemoteIngressProtocolDTLSCustomOverlay
	case RuntimeRemoteEndpointRoleWireGuardRawDatagram:
		return RuntimeRemoteIngressProtocolRawWireGuard
	case RuntimeRemoteEndpointRoleUDPProtocolMultiplexer:
		return RuntimeRemoteIngressProtocolUDPProtocolMux
	default:
		return ""
	}
}

func selectRuntimeExecutionPlanDescriptor(
	descriptors []RuntimeExecutionPlanDescriptor,
	requested *RuntimeExecutionPlan,
) (*RuntimeExecutionPlanDescriptor, error) {
	if len(descriptors) == 0 {
		if requested == nil {
			return nil, errRuntimeExecutionPlanUnavailable
		}
		return nil, errRuntimeExecutionPlanUnsupported
	}

	if requested != nil {
		for _, descriptor := range descriptors {
			if !runtimeExecutionPlanEquals(descriptor.Plan, *requested) {
				continue
			}
			if descriptor.SupportState != RuntimeExecutionPlanSupportStateSupported {
				return &descriptor, fmt.Errorf("%w: %s", errRuntimeExecutionPlanUnavailable, runtimeExecutionPlanUnavailableMessage(descriptor))
			}
			return &descriptor, nil
		}
		return nil, errRuntimeExecutionPlanUnsupported
	}

	var defaultPlan *RuntimeExecutionPlanDescriptor
	defaultSupported := 0
	supported := 0
	for _, descriptor := range descriptors {
		if descriptor.SupportState != RuntimeExecutionPlanSupportStateSupported {
			continue
		}
		supported++
		if descriptor.Default {
			defaultSupported++
			if defaultPlan == nil {
				copyDescriptor := descriptor
				defaultPlan = &copyDescriptor
			}
		}
	}
	switch {
	case defaultSupported == 1:
		return defaultPlan, nil
	case defaultSupported > 1:
		return nil, errRuntimeExecutionPlanSelectionRequired
	case supported == 1:
		for _, descriptor := range descriptors {
			if descriptor.SupportState == RuntimeExecutionPlanSupportStateSupported {
				copyDescriptor := descriptor
				return &copyDescriptor, nil
			}
		}
	case supported == 0:
		return nil, errRuntimeExecutionPlanUnavailable
	}
	return nil, errRuntimeExecutionPlanSelectionRequired
}

func selectPlatformTunnelExecutionPlanDescriptor(
	descriptors []RuntimeExecutionPlanDescriptor,
	requested *RuntimeExecutionPlan,
) (*RuntimeExecutionPlanDescriptor, error) {
	if len(descriptors) == 0 {
		if requested == nil {
			return nil, errRuntimeExecutionPlanUnavailable
		}
		return nil, errRuntimeExecutionPlanUnsupported
	}
	if requested != nil {
		for _, descriptor := range descriptors {
			if runtimeExecutionPlanEquals(descriptor.Plan, *requested) {
				copyDescriptor := descriptor
				return &copyDescriptor, nil
			}
		}
		return nil, errRuntimeExecutionPlanUnsupported
	}
	for _, descriptor := range descriptors {
		if descriptor.Default {
			copyDescriptor := descriptor
			return &copyDescriptor, nil
		}
	}
	if len(descriptors) == 1 {
		copyDescriptor := descriptors[0]
		return &copyDescriptor, nil
	}
	return nil, errRuntimeExecutionPlanSelectionRequired
}

func runtimeExecutionPlanUnavailableMessage(descriptor RuntimeExecutionPlanDescriptor) string {
	if strings.TrimSpace(descriptor.Message) != "" {
		return descriptor.Message
	}
	switch descriptor.SupportState {
	case RuntimeExecutionPlanSupportStateExperimental:
		return "requested runtime execution plan is experimental and not startable on this host"
	case RuntimeExecutionPlanSupportStateUnavailable:
		return "requested runtime execution plan is unavailable on this host"
	default:
		return "requested runtime execution plan is unavailable"
	}
}

func isKnownRuntimeAccessMethod(method RuntimeAccessMethod) bool {
	switch method {
	case RuntimeAccessMethodTURNCredentials, RuntimeAccessMethodWebRTCCallAttach:
		return true
	default:
		return false
	}
}

func isKnownRuntimeCarrierFamily(family RuntimeCarrierFamily) bool {
	switch family {
	case RuntimeCarrierFamilyTURNDatagram,
		RuntimeCarrierFamilyTURNDTLSOverlay,
		RuntimeCarrierFamilyWebRTCDataChannel:
		return true
	default:
		return false
	}
}

func isKnownRuntimeEngineFamily(family RuntimeEngineFamily) bool {
	switch family {
	case RuntimeEngineFamilyWireGuardNative,
		RuntimeEngineFamilyCustomPacketOverlay,
		RuntimeEngineFamilyProxyCoreAdapter,
		RuntimeEngineFamilyTrustTunnelNative:
		return true
	default:
		return false
	}
}

func isKnownRuntimeHostAdapter(adapter RuntimeHostAdapter) bool {
	switch adapter {
	case RuntimeHostAdapterAndroidVPNService,
		RuntimeHostAdapterAppleNetworkExtension,
		RuntimeHostAdapterWindowsWintun,
		RuntimeHostAdapterLinuxTun:
		return true
	default:
		return false
	}
}

func isKnownRuntimeExecutionPlanSupportState(state RuntimeExecutionPlanSupportState) bool {
	switch state {
	case RuntimeExecutionPlanSupportStateSupported,
		RuntimeExecutionPlanSupportStateUnavailable,
		RuntimeExecutionPlanSupportStateExperimental:
		return true
	default:
		return false
	}
}

func isKnownRuntimeRemoteEndpointFamily(family RuntimeRemoteEndpointFamily) bool {
	switch family {
	case RuntimeRemoteEndpointFamilyTURNServer,
		RuntimeRemoteEndpointFamilyWebRTCCallEndpoint,
		RuntimeRemoteEndpointFamilyHTTPSTunnelServer:
		return true
	default:
		return false
	}
}

func isKnownRuntimeRemoteEndpointRole(role RuntimeRemoteEndpointRole) bool {
	switch role {
	case RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
		RuntimeRemoteEndpointRoleWireGuardRawDatagram,
		RuntimeRemoteEndpointRoleUDPProtocolMultiplexer:
		return true
	default:
		return false
	}
}

func validateRuntimeRemoteIngressDiagnostics(
	diagnostics RuntimeRemoteIngressDiagnostics,
) error {
	if !isKnownRuntimeRemoteEndpointFamily(diagnostics.EndpointFamily) {
		return fmt.Errorf("endpoint_family %q is unknown", diagnostics.EndpointFamily)
	}
	if !isKnownRuntimeRemoteEndpointRole(diagnostics.EndpointRole) {
		return fmt.Errorf("endpoint_role %q is unknown", diagnostics.EndpointRole)
	}
	if !isKnownRuntimeRemoteIngressProtocol(diagnostics.Protocol) {
		return fmt.Errorf("protocol %q is unknown", diagnostics.Protocol)
	}
	if !isKnownRuntimeRemoteIngressIsolation(diagnostics.Isolation) {
		return fmt.Errorf("isolation %q is unknown", diagnostics.Isolation)
	}
	if strings.TrimSpace(diagnostics.Address) == "" {
		return fmt.Errorf("address is missing")
	}
	switch diagnostics.EndpointRole {
	case RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay:
		if diagnostics.Protocol != RuntimeRemoteIngressProtocolDTLSCustomOverlay {
			return fmt.Errorf("endpoint_role %q requires protocol %q, got %q", diagnostics.EndpointRole, RuntimeRemoteIngressProtocolDTLSCustomOverlay, diagnostics.Protocol)
		}
		if diagnostics.Isolation != RuntimeRemoteIngressIsolationDedicated {
			return fmt.Errorf("endpoint_role %q requires isolation %q, got %q", diagnostics.EndpointRole, RuntimeRemoteIngressIsolationDedicated, diagnostics.Isolation)
		}
	case RuntimeRemoteEndpointRoleWireGuardRawDatagram:
		if diagnostics.Protocol != RuntimeRemoteIngressProtocolRawWireGuard {
			return fmt.Errorf("endpoint_role %q requires protocol %q, got %q", diagnostics.EndpointRole, RuntimeRemoteIngressProtocolRawWireGuard, diagnostics.Protocol)
		}
		if diagnostics.Isolation != RuntimeRemoteIngressIsolationDedicated {
			return fmt.Errorf("endpoint_role %q requires isolation %q, got %q", diagnostics.EndpointRole, RuntimeRemoteIngressIsolationDedicated, diagnostics.Isolation)
		}
	case RuntimeRemoteEndpointRoleUDPProtocolMultiplexer:
		if diagnostics.Protocol != RuntimeRemoteIngressProtocolUDPProtocolMux {
			return fmt.Errorf("endpoint_role %q requires protocol %q, got %q", diagnostics.EndpointRole, RuntimeRemoteIngressProtocolUDPProtocolMux, diagnostics.Protocol)
		}
		if diagnostics.Isolation != RuntimeRemoteIngressIsolationMuxBacked {
			return fmt.Errorf("endpoint_role %q requires isolation %q, got %q", diagnostics.EndpointRole, RuntimeRemoteIngressIsolationMuxBacked, diagnostics.Isolation)
		}
	}
	return nil
}

func isKnownRuntimeRemoteIngressProtocol(protocol RuntimeRemoteIngressProtocol) bool {
	switch protocol {
	case RuntimeRemoteIngressProtocolDTLSCustomOverlay,
		RuntimeRemoteIngressProtocolRawWireGuard,
		RuntimeRemoteIngressProtocolUDPProtocolMux:
		return true
	default:
		return false
	}
}

func isKnownRuntimeRemoteIngressIsolation(isolation RuntimeRemoteIngressIsolation) bool {
	switch isolation {
	case RuntimeRemoteIngressIsolationDedicated,
		RuntimeRemoteIngressIsolationMuxBacked:
		return true
	default:
		return false
	}
}
