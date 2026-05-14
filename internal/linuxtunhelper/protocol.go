package linuxtunhelper

import (
	"fmt"
	"regexp"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

var (
	profileStorePathPattern = regexp.MustCompile(`\S*vpn-transport-profiles\S*`)
	windowsDrivePathPattern = regexp.MustCompile(`^[A-Za-z]:[\\/]`)
)

const (
	ProtocolVersion     = 1
	HelperIdentity      = "relaydock-linux-tun-helper"
	maxRequestBodyBytes = 64 * 1024

	redactedAttemptNonce          = "<redacted:attempt-nonce>"
	redactedTURNUsername          = "<redacted:turn-username>"
	redactedTURNPassword          = "<redacted:turn-password>"
	redactedWireGuardPrivateKey   = "<redacted:wireguard-client-private-key>"
	redactedWireGuardPresharedKey = "<redacted:wireguard-preshared-key>"
	redactedProfileStorePath      = "<redacted:profile-store-path>"
)

type Command string

const (
	CommandStart   Command = "start"
	CommandStatus  Command = "status"
	CommandCleanup Command = "cleanup"
)

type NativePolicyDirectives struct {
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy `json:"underlay_route_policy"`
	UnderlayExclusions  []string                                        `json:"underlay_exclusions,omitempty"`
	DNSBypassRequired   bool                                            `json:"dns_bypass_required,omitempty"`
}

type StartRequest struct {
	ProtocolVersion     int                                `json:"protocol_version"`
	HelperCompatibility string                             `json:"helper_compatibility"`
	AttemptID           string                             `json:"attempt_id"`
	AttemptNonce        string                             `json:"attempt_nonce"`
	HostPID             int                                `json:"host_pid"`
	ExecutionPlan       clientcontrol.RuntimeExecutionPlan `json:"execution_plan"`
	Lease               WireGuardTurnLease                 `json:"lease"`
	PolicyDirectives    NativePolicyDirectives             `json:"policy_directives"`
}

type WireGuardTurnLease struct {
	AccessMethod               clientcontrol.RuntimeAccessMethod         `json:"access_method,omitempty"`
	CarrierFamily              clientcontrol.RuntimeCarrierFamily        `json:"carrier_family,omitempty"`
	EngineFamily               clientcontrol.RuntimeEngineFamily         `json:"engine_family,omitempty"`
	RemoteEndpointFamily       clientcontrol.RuntimeRemoteEndpointFamily `json:"remote_endpoint_family,omitempty"`
	RemoteEndpointRole         clientcontrol.RuntimeRemoteEndpointRole   `json:"remote_endpoint_role,omitempty"`
	TURNServerAddress          string                                    `json:"turn_server_address"`
	TURNUsername               string                                    `json:"turn_username,omitempty"`
	TURNPassword               string                                    `json:"turn_password,omitempty"`
	PeerEndpointAddress        string                                    `json:"peer_endpoint_address,omitempty"`
	ClientPrivateKey           string                                    `json:"client_private_key,omitempty"`
	ClientAddresses            []string                                  `json:"client_addresses,omitempty"`
	PeerPublicKey              string                                    `json:"peer_public_key,omitempty"`
	PresharedKey               string                                    `json:"preshared_key,omitempty"`
	AllowedIPs                 []string                                  `json:"allowed_ips,omitempty"`
	DNSServers                 []string                                  `json:"dns_servers,omitempty"`
	MTU                        int                                       `json:"mtu,omitempty"`
	PersistentKeepaliveSeconds int                                       `json:"persistent_keepalive_seconds,omitempty"`
	ExpiresAt                  *time.Time                                `json:"expires_at,omitempty"`
}

type AttemptRequest struct {
	ProtocolVersion int    `json:"protocol_version"`
	AttemptID       string `json:"attempt_id"`
	AttemptNonce    string `json:"attempt_nonce"`
}

type Diagnostic struct {
	Code     string `json:"code"`
	Message  string `json:"message,omitempty"`
	Redacted bool   `json:"redacted,omitempty"`
}

type Response struct {
	ProtocolVersion     int                                             `json:"protocol_version"`
	HelperIdentity      string                                          `json:"helper_identity"`
	OK                  bool                                            `json:"ok"`
	ErrorCode           string                                          `json:"error_code,omitempty"`
	Message             string                                          `json:"message,omitempty"`
	Stage               clientcontrol.PlatformTunnelStartupStage        `json:"stage,omitempty"`
	MissingPrerequisite clientcontrol.PlatformTunnelPrerequisite        `json:"missing_prerequisite,omitempty"`
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy `json:"underlay_route_policy,omitempty"`
	UnderlayExclusions  []string                                        `json:"underlay_exclusions,omitempty"`
	Dataplane           *clientcontrol.PlatformTunnelDataplaneEvidence  `json:"dataplane,omitempty"`
	Diagnostics         []Diagnostic                                    `json:"diagnostics,omitempty"`
}

func NewWireGuardTurnLease(lease clientcontrol.WireGuardTurnExecutionLease) WireGuardTurnLease {
	var expiresAt *time.Time
	if lease.ExpiresAt != nil {
		value := lease.ExpiresAt.UTC()
		expiresAt = &value
	}
	return WireGuardTurnLease{
		AccessMethod:               lease.AccessMethod,
		CarrierFamily:              lease.CarrierFamily,
		EngineFamily:               lease.EngineFamily,
		RemoteEndpointFamily:       lease.RemoteEndpointFamily,
		RemoteEndpointRole:         lease.RemoteEndpointRole,
		TURNServerAddress:          strings.TrimSpace(lease.TURNServerAddress),
		TURNUsername:               strings.TrimSpace(lease.TURNUsername),
		TURNPassword:               strings.TrimSpace(lease.TURNPassword),
		PeerEndpointAddress:        strings.TrimSpace(lease.PeerEndpointAddress),
		ClientPrivateKey:           strings.TrimSpace(lease.ClientPrivateKey),
		ClientAddresses:            append([]string(nil), lease.ClientAddresses...),
		PeerPublicKey:              strings.TrimSpace(lease.PeerPublicKey),
		PresharedKey:               strings.TrimSpace(lease.PresharedKey),
		AllowedIPs:                 append([]string(nil), lease.AllowedIPs...),
		DNSServers:                 append([]string(nil), lease.DNSServers...),
		MTU:                        lease.MTU,
		PersistentKeepaliveSeconds: lease.PersistentKeepaliveSeconds,
		ExpiresAt:                  expiresAt,
	}
}

func (r StartRequest) validate() error {
	if err := validateProtocolVersion(r.ProtocolVersion); err != nil {
		return err
	}
	if strings.TrimSpace(r.HelperCompatibility) != HelperIdentity {
		return fmt.Errorf("helper_compatibility must match %s", HelperIdentity)
	}
	if strings.TrimSpace(r.AttemptID) == "" {
		return fmt.Errorf("attempt_id is required")
	}
	if strings.TrimSpace(r.AttemptNonce) == "" {
		return fmt.Errorf("attempt_nonce is required")
	}
	if r.HostPID <= 0 {
		return fmt.Errorf("host_pid is required")
	}
	if r.ExecutionPlan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
		return fmt.Errorf("execution_plan.host_adapter must be linux_tun")
	}
	if strings.TrimSpace(r.Lease.TURNServerAddress) == "" {
		return fmt.Errorf("lease.turn_server_address is required")
	}
	if err := r.Lease.validate(); err != nil {
		return err
	}
	if err := r.PolicyDirectives.validate(); err != nil {
		return err
	}
	if r.PolicyDirectives.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		return fmt.Errorf("policy_directives.underlay_route_policy must be preserve_active_local_network")
	}
	return nil
}

func (r AttemptRequest) validate() error {
	if err := validateProtocolVersion(r.ProtocolVersion); err != nil {
		return err
	}
	if strings.TrimSpace(r.AttemptID) == "" {
		return fmt.Errorf("attempt_id is required")
	}
	if strings.TrimSpace(r.AttemptNonce) == "" {
		return fmt.Errorf("attempt_nonce is required")
	}
	return nil
}

func (p NativePolicyDirectives) validate() error {
	for _, exclusion := range p.UnderlayExclusions {
		if err := validateNotFilePath("policy_directives.underlay_exclusions", exclusion); err != nil {
			return err
		}
	}
	return nil
}

func (l WireGuardTurnLease) validate() error {
	for field, value := range map[string]string{
		"lease.turn_server_address":   l.TURNServerAddress,
		"lease.peer_endpoint_address": l.PeerEndpointAddress,
	} {
		if err := validateNotFilePath(field, value); err != nil {
			return err
		}
	}
	for _, address := range l.ClientAddresses {
		if err := validateNotFilePath("lease.client_addresses", address); err != nil {
			return err
		}
	}
	for _, allowedIP := range l.AllowedIPs {
		if err := validateNotFilePath("lease.allowed_ips", allowedIP); err != nil {
			return err
		}
	}
	for _, dnsServer := range l.DNSServers {
		if err := validateNotFilePath("lease.dns_servers", dnsServer); err != nil {
			return err
		}
	}
	return nil
}

func (l WireGuardTurnLease) toClientControlLease() clientcontrol.WireGuardTurnExecutionLease {
	var expiresAt *time.Time
	if l.ExpiresAt != nil {
		value := l.ExpiresAt.UTC()
		expiresAt = &value
	}
	return clientcontrol.WireGuardTurnExecutionLease{
		AccessMethod:               l.AccessMethod,
		CarrierFamily:              l.CarrierFamily,
		EngineFamily:               l.EngineFamily,
		RemoteEndpointFamily:       l.RemoteEndpointFamily,
		RemoteEndpointRole:         l.RemoteEndpointRole,
		TURNServerAddress:          strings.TrimSpace(l.TURNServerAddress),
		TURNUsername:               strings.TrimSpace(l.TURNUsername),
		TURNPassword:               strings.TrimSpace(l.TURNPassword),
		PeerEndpointAddress:        strings.TrimSpace(l.PeerEndpointAddress),
		ClientPrivateKey:           strings.TrimSpace(l.ClientPrivateKey),
		ClientAddresses:            append([]string(nil), l.ClientAddresses...),
		PeerPublicKey:              strings.TrimSpace(l.PeerPublicKey),
		PresharedKey:               strings.TrimSpace(l.PresharedKey),
		AllowedIPs:                 append([]string(nil), l.AllowedIPs...),
		DNSServers:                 append([]string(nil), l.DNSServers...),
		MTU:                        l.MTU,
		PersistentKeepaliveSeconds: l.PersistentKeepaliveSeconds,
		ExpiresAt:                  expiresAt,
	}
}

func validateNotFilePath(field string, value string) error {
	trimmed := strings.TrimSpace(value)
	if trimmed == "" {
		return nil
	}
	if strings.HasPrefix(trimmed, "/") ||
		strings.HasPrefix(trimmed, "./") ||
		strings.HasPrefix(trimmed, "../") ||
		strings.HasPrefix(trimmed, "~") ||
		strings.HasPrefix(strings.ToLower(trimmed), "file:") ||
		strings.Contains(trimmed, `\`) ||
		windowsDrivePathPattern.MatchString(trimmed) {
		return fmt.Errorf("%s must not be a file path", field)
	}
	return nil
}

func validateProtocolVersion(version int) error {
	if version != ProtocolVersion {
		return fmt.Errorf("unsupported protocol_version %d", version)
	}
	return nil
}

type diagnosticSecret struct {
	value      string
	redactedAs string
}

func (r StartRequest) diagnosticSecrets() []diagnosticSecret {
	secrets := []diagnosticSecret{
		{value: r.AttemptNonce, redactedAs: redactedAttemptNonce},
	}
	secrets = append(secrets, r.Lease.diagnosticSecrets()...)
	return secrets
}

func (r AttemptRequest) diagnosticSecrets() []diagnosticSecret {
	return []diagnosticSecret{{value: r.AttemptNonce, redactedAs: redactedAttemptNonce}}
}

func (l WireGuardTurnLease) diagnosticSecrets() []diagnosticSecret {
	return []diagnosticSecret{
		{value: l.TURNUsername, redactedAs: redactedTURNUsername},
		{value: l.TURNPassword, redactedAs: redactedTURNPassword},
		{value: l.ClientPrivateKey, redactedAs: redactedWireGuardPrivateKey},
		{value: l.PresharedKey, redactedAs: redactedWireGuardPresharedKey},
	}
}

func errorResponse(code string, err error, secrets ...diagnosticSecret) Response {
	return errorResponseWithStage(code, "", "", err, secrets...)
}

func errorResponseWithStage(
	code string,
	stage clientcontrol.PlatformTunnelStartupStage,
	prerequisite clientcontrol.PlatformTunnelPrerequisite,
	err error,
	secrets ...diagnosticSecret,
) Response {
	message := ""
	redacted := false
	if err != nil {
		message, redacted = redactDiagnosticMessage(err.Error(), secrets...)
	}
	response := Response{
		ProtocolVersion:     ProtocolVersion,
		HelperIdentity:      HelperIdentity,
		OK:                  false,
		ErrorCode:           strings.TrimSpace(code),
		Message:             message,
		Stage:               stage,
		MissingPrerequisite: prerequisite,
	}
	if message != "" {
		response.Diagnostics = []Diagnostic{{
			Code:     response.ErrorCode,
			Message:  message,
			Redacted: redacted,
		}}
	}
	return response
}

type nativeStartResult struct {
	UnderlayRoutePolicy clientcontrol.PlatformTunnelUnderlayRoutePolicy
	UnderlayExclusions  []string
	Dataplane           *clientcontrol.PlatformTunnelDataplaneEvidence
}

func successResponse(result nativeStartResult) Response {
	return Response{
		ProtocolVersion:     ProtocolVersion,
		HelperIdentity:      HelperIdentity,
		OK:                  true,
		UnderlayRoutePolicy: result.UnderlayRoutePolicy,
		UnderlayExclusions:  append([]string(nil), result.UnderlayExclusions...),
		Dataplane:           cloneDataplaneEvidence(result.Dataplane),
	}
}

func cloneDataplaneEvidence(evidence *clientcontrol.PlatformTunnelDataplaneEvidence) *clientcontrol.PlatformTunnelDataplaneEvidence {
	if evidence == nil {
		return nil
	}
	clone := *evidence
	return &clone
}

func redactDiagnosticMessage(message string, secrets ...diagnosticSecret) (string, bool) {
	redacted := strings.TrimSpace(message)
	changed := false
	redacted = profileStorePathPattern.ReplaceAllStringFunc(redacted, func(_ string) string {
		changed = true
		return redactedProfileStorePath
	})
	for _, secret := range secrets {
		value := strings.TrimSpace(secret.value)
		if value == "" || secret.redactedAs == "" {
			continue
		}
		if strings.Contains(redacted, value) {
			redacted = strings.ReplaceAll(redacted, value, secret.redactedAs)
			changed = true
		}
	}
	return redacted, changed
}
