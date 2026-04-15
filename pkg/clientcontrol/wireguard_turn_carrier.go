package clientcontrol

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const WireGuardTurnRemoteEndpointRoleDatagramTermination = "wireguard_turn_datagram_termination"

var errWireGuardTurnCarrierLeaseInvalid = errors.New("strict TURN datagram WireGuard carrier lease is invalid")

type WireGuardTurnMaterializeRequest struct {
	ResolutionID string
	Descriptor   RuntimeExecutionPlanDescriptor
	Credentials  provider.Credentials
	Defaults     RuntimeDefaults
}

type WireGuardTurnExecutionLease struct {
	ResolutionID         string
	AccessMethod         RuntimeAccessMethod
	CarrierFamily        RuntimeCarrierFamily
	EngineFamily         RuntimeEngineFamily
	RemoteEndpointFamily RuntimeRemoteEndpointFamily
	RemoteEndpointRole   string
	TURNServerAddress    string
	TURNUsername         string
	TURNPassword         string
	ClientPrivateKey     string
	ClientAddresses      []string
	PeerPublicKey        string
	AllowedIPs           []string
	DNSServers           []string
	MTU                  int
	ExpiresAt            *time.Time
}

type WireGuardTurnMaterializer func(context.Context, WireGuardTurnMaterializeRequest) (*WireGuardTurnExecutionLease, error)

func WithWireGuardTurnMaterializer(materializer WireGuardTurnMaterializer) Option {
	return func(cfg *hostConfig) {
		cfg.wireGuardTurnMaterializer = materializer
	}
}

func cloneWireGuardTurnExecutionLease(lease *WireGuardTurnExecutionLease) *WireGuardTurnExecutionLease {
	if lease == nil {
		return nil
	}
	clone := *lease
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
	return &clone
}

func isStrictWireGuardTurnExecutionPlan(plan RuntimeExecutionPlan) bool {
	return plan.AccessMethod == RuntimeAccessMethodTURNCredentials &&
		plan.CarrierFamily == RuntimeCarrierFamilyTURNDatagram &&
		plan.EngineFamily == RuntimeEngineFamilyWireGuardNative &&
		strings.TrimSpace(string(plan.HostAdapter)) != ""
}

func strictWireGuardTurnCarrierMessage(build BuildIdentity, mode PlatformTunnelMode) string {
	return fmt.Sprintf(
		"The %s host does not yet implement the strict TURN datagram WireGuard carrier/materializer required for mode %s.",
		hostTargetLabel(build),
		mode,
	)
}

func applyWireGuardTurnCarrierAvailability(
	capabilities []PlatformTunnelCapability,
	build BuildIdentity,
	materializer WireGuardTurnMaterializer,
) []PlatformTunnelCapability {
	snapshot := clonePlatformTunnelCapabilities(capabilities)
	if materializer != nil {
		return snapshot
	}

	for index := range snapshot {
		capability := &snapshot[index]
		downgraded := false
		for planIndex := range capability.ExecutionPlans {
			descriptor := &capability.ExecutionPlans[planIndex]
			if !isStrictWireGuardTurnExecutionPlan(descriptor.Plan) {
				continue
			}
			if descriptor.SupportState == RuntimeExecutionPlanSupportStateSupported {
				descriptor.SupportState = RuntimeExecutionPlanSupportStateUnavailable
				downgraded = true
			}
			descriptor.Message = firstNonEmpty(
				strings.TrimSpace(descriptor.Message),
				strictWireGuardTurnCarrierMessage(build, capability.Mode),
			)
		}
		if downgraded {
			capability.Available = false
			capability.MissingPrerequisite = PlatformTunnelPrerequisiteHostImplementation
			capability.Message = firstNonEmpty(
				strings.TrimSpace(capability.Message),
				strictWireGuardTurnCarrierMessage(build, capability.Mode),
			)
		}
	}

	return snapshot
}

func validateWireGuardTurnExecutionLease(
	req WireGuardTurnMaterializeRequest,
	lease *WireGuardTurnExecutionLease,
) error {
	if lease == nil {
		return fmt.Errorf("%w: lease is missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	if strings.TrimSpace(lease.ResolutionID) == "" {
		return fmt.Errorf("%w: resolution_id is missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	if lease.ResolutionID != req.ResolutionID {
		return fmt.Errorf(
			"%w: resolution_id %q does not match %q",
			errWireGuardTurnCarrierLeaseInvalid,
			lease.ResolutionID,
			req.ResolutionID,
		)
	}
	if lease.AccessMethod != req.Descriptor.Plan.AccessMethod {
		return fmt.Errorf("%w: access_method %q does not match %q", errWireGuardTurnCarrierLeaseInvalid, lease.AccessMethod, req.Descriptor.Plan.AccessMethod)
	}
	if lease.CarrierFamily != req.Descriptor.Plan.CarrierFamily {
		return fmt.Errorf("%w: carrier_family %q does not match %q", errWireGuardTurnCarrierLeaseInvalid, lease.CarrierFamily, req.Descriptor.Plan.CarrierFamily)
	}
	if lease.EngineFamily != req.Descriptor.Plan.EngineFamily {
		return fmt.Errorf("%w: engine_family %q does not match %q", errWireGuardTurnCarrierLeaseInvalid, lease.EngineFamily, req.Descriptor.Plan.EngineFamily)
	}
	if lease.RemoteEndpointFamily != req.Descriptor.RemoteEndpointFamily {
		return fmt.Errorf(
			"%w: remote_endpoint_family %q does not match %q",
			errWireGuardTurnCarrierLeaseInvalid,
			lease.RemoteEndpointFamily,
			req.Descriptor.RemoteEndpointFamily,
		)
	}
	if strings.TrimSpace(lease.RemoteEndpointRole) == "" {
		return fmt.Errorf("%w: remote_endpoint_role is missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	if strings.TrimSpace(lease.TURNServerAddress) == "" {
		return fmt.Errorf("%w: turn_server_address is missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	if strings.TrimSpace(lease.TURNUsername) == "" || strings.TrimSpace(lease.TURNPassword) == "" {
		return fmt.Errorf("%w: TURN credentials are incomplete", errWireGuardTurnCarrierLeaseInvalid)
	}
	if strings.TrimSpace(lease.ClientPrivateKey) == "" {
		return fmt.Errorf("%w: client_private_key is missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	if len(lease.ClientAddresses) == 0 {
		return fmt.Errorf("%w: client_addresses are missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	if strings.TrimSpace(lease.PeerPublicKey) == "" {
		return fmt.Errorf("%w: peer_public_key is missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	if len(lease.AllowedIPs) == 0 {
		return fmt.Errorf("%w: allowed_ips are missing", errWireGuardTurnCarrierLeaseInvalid)
	}
	return nil
}

func (h *Host) materializeWireGuardTurnLease(
	ctx context.Context,
	resolutionID string,
	descriptor RuntimeExecutionPlanDescriptor,
	credentials provider.Credentials,
	defaults RuntimeDefaults,
) (*WireGuardTurnExecutionLease, error) {
	if h.wireGuardTurnMaterializer == nil {
		return nil, fmt.Errorf(
			"%w: strict TURN datagram WireGuard carrier materializer is not configured on this host",
			errRuntimeExecutionPlanUnavailable,
		)
	}

	request := WireGuardTurnMaterializeRequest{
		ResolutionID: resolutionID,
		Descriptor:   descriptor,
		Credentials:  credentials,
		Defaults:     defaults,
	}
	lease, err := h.wireGuardTurnMaterializer(ctx, request)
	if err != nil {
		return nil, fmt.Errorf(
			"%w: strict TURN datagram WireGuard carrier materialization failed: %v",
			errRuntimeExecutionPlanUnavailable,
			err,
		)
	}
	if err := validateWireGuardTurnExecutionLease(request, lease); err != nil {
		return nil, fmt.Errorf("%w: %v", errRuntimeExecutionPlanUnavailable, err)
	}
	return cloneWireGuardTurnExecutionLease(lease), nil
}
