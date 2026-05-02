package clientcontrol

type RuntimeAccessMethod string

const (
	RuntimeAccessMethodTURNCredentials  RuntimeAccessMethod = "turn_credentials"
	RuntimeAccessMethodWebRTCCallAttach RuntimeAccessMethod = "webrtc_call_attach"
)

type RuntimeCarrierFamily string

const (
	RuntimeCarrierFamilyTURNDatagram      RuntimeCarrierFamily = "turn_datagram"
	RuntimeCarrierFamilyTURNDTLSOverlay   RuntimeCarrierFamily = "turn_dtls_overlay"
	RuntimeCarrierFamilyWebRTCDataChannel RuntimeCarrierFamily = "webrtc_datachannel"
)

type RuntimeEngineFamily string

const (
	RuntimeEngineFamilyWireGuardNative     RuntimeEngineFamily = "wireguard_native"
	RuntimeEngineFamilyCustomPacketOverlay RuntimeEngineFamily = "custom_packet_overlay"
	RuntimeEngineFamilyProxyCoreAdapter    RuntimeEngineFamily = "proxy_core_adapter"
	RuntimeEngineFamilyTrustTunnelNative   RuntimeEngineFamily = "trusttunnel_native"
)

type RuntimeHostAdapter string

const (
	RuntimeHostAdapterAndroidVPNService     RuntimeHostAdapter = "android_vpn_service"
	RuntimeHostAdapterAppleNetworkExtension RuntimeHostAdapter = "apple_network_extension"
	RuntimeHostAdapterWindowsWintun         RuntimeHostAdapter = "windows_wintun"
	RuntimeHostAdapterLinuxTun              RuntimeHostAdapter = "linux_tun"
)

type RuntimeExecutionPlanSupportState string

const (
	RuntimeExecutionPlanSupportStateSupported    RuntimeExecutionPlanSupportState = "supported"
	RuntimeExecutionPlanSupportStateUnavailable  RuntimeExecutionPlanSupportState = "unavailable"
	RuntimeExecutionPlanSupportStateExperimental RuntimeExecutionPlanSupportState = "experimental"
)

type RuntimeRemoteEndpointFamily string

const (
	RuntimeRemoteEndpointFamilyTURNServer         RuntimeRemoteEndpointFamily = "turn_server"
	RuntimeRemoteEndpointFamilyWebRTCCallEndpoint RuntimeRemoteEndpointFamily = "webrtc_call_endpoint"
	RuntimeRemoteEndpointFamilyHTTPSTunnelServer  RuntimeRemoteEndpointFamily = "https_tunnel_server"
)

type RuntimeRemoteEndpointRole string

const (
	RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay  RuntimeRemoteEndpointRole = "turn_dtls_custom_overlay"
	RuntimeRemoteEndpointRoleWireGuardRawDatagram   RuntimeRemoteEndpointRole = "wireguard_raw_datagram"
	RuntimeRemoteEndpointRoleUDPProtocolMultiplexer RuntimeRemoteEndpointRole = "udp_protocol_multiplexer"
)

type RuntimeRemoteIngressProtocol string

const (
	RuntimeRemoteIngressProtocolDTLSCustomOverlay RuntimeRemoteIngressProtocol = "dtls_custom_overlay"
	RuntimeRemoteIngressProtocolRawWireGuard      RuntimeRemoteIngressProtocol = "raw_wireguard_datagram"
	RuntimeRemoteIngressProtocolUDPProtocolMux    RuntimeRemoteIngressProtocol = "udp_protocol_multiplexer"
)

type RuntimeRemoteIngressIsolation string

const (
	RuntimeRemoteIngressIsolationDedicated RuntimeRemoteIngressIsolation = "dedicated"
	RuntimeRemoteIngressIsolationMuxBacked RuntimeRemoteIngressIsolation = "mux_backed"
)

type RuntimeRemoteIngressDiagnostics struct {
	EndpointFamily RuntimeRemoteEndpointFamily   `json:"endpoint_family,omitempty"`
	EndpointRole   RuntimeRemoteEndpointRole     `json:"endpoint_role,omitempty"`
	Protocol       RuntimeRemoteIngressProtocol  `json:"protocol,omitempty"`
	Address        string                        `json:"address,omitempty"`
	Isolation      RuntimeRemoteIngressIsolation `json:"isolation,omitempty"`
}

type RuntimeExecutionPlan struct {
	AccessMethod  RuntimeAccessMethod  `json:"access_method"`
	CarrierFamily RuntimeCarrierFamily `json:"carrier_family"`
	EngineFamily  RuntimeEngineFamily  `json:"engine_family"`
	HostAdapter   RuntimeHostAdapter   `json:"host_adapter,omitempty"`
}

type RuntimeExecutionPlanDescriptor struct {
	Plan                          RuntimeExecutionPlan                `json:"plan"`
	SupportState                  RuntimeExecutionPlanSupportState    `json:"support_state"`
	RemoteEndpointFamily          RuntimeRemoteEndpointFamily         `json:"remote_endpoint_family"`
	RemoteEndpointRole            RuntimeRemoteEndpointRole           `json:"remote_endpoint_role,omitempty"`
	Default                       bool                                `json:"default,omitempty"`
	RequiresCapability            Capability                          `json:"requires_capability,omitempty"`
	RequiredTransportProfileKinds []TransportProfileKind              `json:"required_transport_profile_kinds,omitempty"`
	TransportProfile              *TransportProfilePrerequisiteStatus `json:"transport_profile,omitempty"`
	Message                       string                              `json:"message,omitempty"`
}

func cloneRuntimeExecutionPlan(plan *RuntimeExecutionPlan) *RuntimeExecutionPlan {
	if plan == nil {
		return nil
	}
	clone := *plan
	return &clone
}

func cloneRuntimeExecutionPlanDescriptors(descriptors []RuntimeExecutionPlanDescriptor) []RuntimeExecutionPlanDescriptor {
	if len(descriptors) == 0 {
		return nil
	}
	out := make([]RuntimeExecutionPlanDescriptor, 0, len(descriptors))
	for _, descriptor := range descriptors {
		clone := descriptor
		if len(descriptor.RequiredTransportProfileKinds) > 0 {
			clone.RequiredTransportProfileKinds = append([]TransportProfileKind(nil), descriptor.RequiredTransportProfileKinds...)
		}
		if descriptor.TransportProfile != nil {
			clone.TransportProfile = cloneTransportProfilePrerequisiteStatus(descriptor.TransportProfile)
		}
		out = append(out, clone)
	}
	return out
}

func cloneRuntimeRemoteIngressDiagnostics(
	diagnostics *RuntimeRemoteIngressDiagnostics,
) *RuntimeRemoteIngressDiagnostics {
	if diagnostics == nil {
		return nil
	}
	clone := *diagnostics
	return &clone
}

func runtimeExecutionPlanEquals(left, right RuntimeExecutionPlan) bool {
	return left.AccessMethod == right.AccessMethod &&
		left.CarrierFamily == right.CarrierFamily &&
		left.EngineFamily == right.EngineFamily &&
		left.HostAdapter == right.HostAdapter
}
