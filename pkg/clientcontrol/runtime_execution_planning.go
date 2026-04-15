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

type RuntimeExecutionPlan struct {
	AccessMethod  RuntimeAccessMethod  `json:"access_method"`
	CarrierFamily RuntimeCarrierFamily `json:"carrier_family"`
	EngineFamily  RuntimeEngineFamily  `json:"engine_family"`
	HostAdapter   RuntimeHostAdapter   `json:"host_adapter,omitempty"`
}

type RuntimeExecutionPlanDescriptor struct {
	Plan                 RuntimeExecutionPlan             `json:"plan"`
	SupportState         RuntimeExecutionPlanSupportState `json:"support_state"`
	RemoteEndpointFamily RuntimeRemoteEndpointFamily      `json:"remote_endpoint_family"`
	Default              bool                             `json:"default,omitempty"`
	RequiresCapability   Capability                       `json:"requires_capability,omitempty"`
	Message              string                           `json:"message,omitempty"`
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
		out = append(out, descriptor)
	}
	return out
}

func runtimeExecutionPlanEquals(left, right RuntimeExecutionPlan) bool {
	return left.AccessMethod == right.AccessMethod &&
		left.CarrierFamily == right.CarrierFamily &&
		left.EngineFamily == right.EngineFamily &&
		left.HostAdapter == right.HostAdapter
}
