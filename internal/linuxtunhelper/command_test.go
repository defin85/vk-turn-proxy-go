package linuxtunhelper

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestRunRejectsPublicEndpointFlags(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	code := Run(strings.NewReader(`{}`), &stdout, &stderr, []string{"-listen", "127.0.0.1:0"})

	if code != exitUsage {
		t.Fatalf("Run() code = %d, want %d", code, exitUsage)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.OK {
		t.Fatal("response.OK = true, want false")
	}
	if response.ErrorCode != "usage" {
		t.Fatalf("response.ErrorCode = %q, want usage", response.ErrorCode)
	}
}

func TestRunStartRejectsProviderFields(t *testing.T) {
	var stdout bytes.Buffer
	request := `{
		"protocol_version": 1,
		"helper_compatibility": "relaydock-linux-tun-helper",
		"attempt_id": "attempt-1",
		"attempt_nonce": "nonce-1",
		"provider": "vk",
		"execution_plan": {"host_adapter": "linux_tun"},
		"lease": {"turn_server_address": "turn.example.test:3478"},
		"policy_directives": {"underlay_route_policy": "preserve_active_local_network"}
	}`

	code := Run(strings.NewReader(request), &stdout, &bytes.Buffer{}, []string{"start"})

	if code != exitInvalidRequest {
		t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "invalid_request" {
		t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
	}
	if !strings.Contains(response.Message, "unknown field") {
		t.Fatalf("response.Message = %q, want unknown field detail", response.Message)
	}
}

func TestRunStartRejectsNonEphemeralUnknownInputs(t *testing.T) {
	for _, tc := range []struct {
		name   string
		extra  string
		leaked string
	}{
		{name: "provider id", extra: `"provider_id": "vk",`, leaked: "vk"},
		{name: "provider link", extra: `"provider_link": "https://vk.com/call/join/secret-token",`, leaked: "secret-token"},
		{name: "browser settings", extra: `"browser_settings": {"profile": "/tmp/browser-profile-secret"},`, leaked: "browser-profile-secret"},
		{name: "profile store path", extra: `"profile_store_path": "/var/lib/relaydock/vpn-transport-profiles/store.json",`, leaked: "/var/lib/relaydock"},
		{name: "shell persistence path", extra: `"shell_persistence_path": "/tmp/relaydock-clientd-env",`, leaked: "/tmp/relaydock-clientd-env"},
		{name: "command field", extra: `"command": "start-clientd-as-root",`, leaked: "start-clientd-as-root"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var stdout bytes.Buffer
			request := fmt.Sprintf(`{
				"protocol_version": 1,
				"helper_compatibility": "relaydock-linux-tun-helper",
				"attempt_id": "attempt-1",
				"attempt_nonce": "nonce-1",
				%s
				"execution_plan": {"host_adapter": "linux_tun"},
				"lease": {"turn_server_address": "turn.example.test:3478"},
				"policy_directives": {"underlay_route_policy": "preserve_active_local_network"}
			}`, tc.extra)

			code := Run(strings.NewReader(request), &stdout, &bytes.Buffer{}, []string{"start"})

			if code != exitInvalidRequest {
				t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
			}
			response := decodeResponse(t, stdout.Bytes())
			if response.ErrorCode != "invalid_request" {
				t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
			}
			if !strings.Contains(response.Message, "unknown field") {
				t.Fatalf("response.Message = %q, want unknown field detail", response.Message)
			}
			if tc.leaked != "" && strings.Contains(response.Message, tc.leaked) {
				t.Fatalf("response.Message leaked %q: %q", tc.leaked, response.Message)
			}
		})
	}
}

func TestNewWireGuardTurnLeaseOmitsHostOwnedResolutionState(t *testing.T) {
	lease := NewWireGuardTurnLease(clientcontrol.WireGuardTurnExecutionLease{
		ResolutionID:        "resolution-secret",
		TURNServerAddress:   "turn.example.test:3478",
		TURNUsername:        "turn-user-secret",
		TURNPassword:        "turn-password-secret",
		PeerEndpointAddress: "raw-wg.example.test:56042",
		ClientPrivateKey:    "client-private-key-secret",
		ClientAddresses:     []string{"10.10.0.2/32"},
		PeerPublicKey:       "peer-public-key",
		AllowedIPs:          []string{"0.0.0.0/0"},
	})
	body, err := json.Marshal(lease)
	if err != nil {
		t.Fatalf("marshal lease: %v", err)
	}
	text := string(body)
	for _, forbidden := range []string{
		"resolution-secret",
		"ResolutionID",
		"resolution_id",
		"provider",
		"profile",
		"browser",
	} {
		if strings.Contains(text, forbidden) {
			t.Fatalf("helper lease payload leaked %q: %s", forbidden, text)
		}
	}
	if !strings.Contains(text, "turn_server_address") {
		t.Fatalf("helper lease payload = %s, want snake-case turn_server_address", text)
	}
}

func TestRunStartRejectsFilePathLikeExecutionInputs(t *testing.T) {
	for _, tc := range []struct {
		name   string
		mutate func(*StartRequest)
		want   string
		leaked string
	}{
		{
			name: "turn server path",
			mutate: func(req *StartRequest) {
				req.Lease.TURNServerAddress = "/tmp/turn-server-secret.sock"
			},
			want:   "lease.turn_server_address must not be a file path",
			leaked: "/tmp/turn-server-secret.sock",
		},
		{
			name: "underlay exclusion path",
			mutate: func(req *StartRequest) {
				req.PolicyDirectives.UnderlayExclusions = []string{"/etc/relaydock/secret-route"}
			},
			want:   "policy_directives.underlay_exclusions must not be a file path",
			leaked: "/etc/relaydock/secret-route",
		},
		{
			name: "windows dns path",
			mutate: func(req *StartRequest) {
				req.Lease.DNSServers = []string{`C:\relaydock\secret-dns`}
			},
			want:   "lease.dns_servers must not be a file path",
			leaked: `C:\relaydock\secret-dns`,
		},
		{
			name: "file uri path",
			mutate: func(req *StartRequest) {
				req.Lease.PeerEndpointAddress = "file:///tmp/relaydock-peer-secret"
			},
			want:   "lease.peer_endpoint_address must not be a file path",
			leaked: "file:///tmp/relaydock-peer-secret",
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var stdout bytes.Buffer
			request := validStartRequestForTest()
			tc.mutate(&request)
			body, err := json.Marshal(request)
			if err != nil {
				t.Fatalf("marshal request: %v", err)
			}

			code := Run(bytes.NewReader(body), &stdout, &bytes.Buffer{}, []string{"start"})

			if code != exitInvalidRequest {
				t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
			}
			response := decodeResponse(t, stdout.Bytes())
			if response.ErrorCode != "invalid_request" {
				t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
			}
			if response.Message != tc.want {
				t.Fatalf("response.Message = %q, want %q", response.Message, tc.want)
			}
			if strings.Contains(response.Message, tc.leaked) {
				t.Fatalf("response.Message leaked %q: %q", tc.leaked, response.Message)
			}
		})
	}
}

func TestRunStartAcceptsNarrowPayloadAndInvokesNativeStart(t *testing.T) {
	restore := overrideStartNativeAttemptForTest(t, func(stdout io.Writer, req StartRequest) int {
		if req.HostPID <= 0 {
			t.Fatalf("host_pid = %d, want positive host pid", req.HostPID)
		}
		writeResponse(stdout, errorResponseWithStage(
			"native_start_failed",
			clientcontrol.PlatformTunnelStartupStageHostBringup,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
			errors.New("native startup failed in fixture"),
			req.diagnosticSecrets()...,
		))
		return exitNativeFailure
	})
	defer restore()
	var stdout bytes.Buffer
	request := validStartRequestForTest()
	body, err := json.Marshal(request)
	if err != nil {
		t.Fatalf("marshal request: %v", err)
	}

	code := Run(bytes.NewReader(body), &stdout, &bytes.Buffer{}, []string{"start"})

	if code != exitNativeFailure {
		t.Fatalf("Run() code = %d, want %d", code, exitNativeFailure)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.OK {
		t.Fatal("response.OK = true, want fail-closed response")
	}
	if response.ErrorCode != "native_start_failed" {
		t.Fatalf("response.ErrorCode = %q, want native_start_failed", response.ErrorCode)
	}
	if response.HelperIdentity != HelperIdentity {
		t.Fatalf("response.HelperIdentity = %q, want %q", response.HelperIdentity, HelperIdentity)
	}
}

func TestRunStatusRejectsUnsupportedProtocolVersion(t *testing.T) {
	var stdout bytes.Buffer
	request := `{"protocol_version": 99, "attempt_id": "attempt-1"}`

	code := Run(strings.NewReader(request), &stdout, &bytes.Buffer{}, []string{"status"})

	if code != exitInvalidRequest {
		t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "invalid_request" {
		t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
	}
	if !strings.Contains(response.Message, "unsupported protocol_version") {
		t.Fatalf("response.Message = %q, want protocol version detail", response.Message)
	}
}

func TestRunStatusRequiresAttemptNonce(t *testing.T) {
	var stdout bytes.Buffer
	request := `{"protocol_version": 1, "attempt_id": "attempt-1"}`

	code := Run(strings.NewReader(request), &stdout, &bytes.Buffer{}, []string{"status"})

	if code != exitInvalidRequest {
		t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "invalid_request" {
		t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
	}
	if !strings.Contains(response.Message, "attempt_nonce is required") {
		t.Fatalf("response.Message = %q, want attempt_nonce detail", response.Message)
	}
}

func TestRunCleanupAcceptsAttemptSchemaAndInvokesNativeCleanup(t *testing.T) {
	restore := overrideCleanupNativeAttemptForTest(t, func(stdout io.Writer, req AttemptRequest) int {
		writeResponse(stdout, errorResponse("cleanup_failed", errors.New("cleanup failed in fixture"), req.diagnosticSecrets()...))
		return exitNativeFailure
	})
	defer restore()
	var stdout bytes.Buffer
	request := `{"protocol_version": 1, "attempt_id": "attempt-1", "attempt_nonce": "nonce-1"}`

	code := Run(strings.NewReader(request), &stdout, &bytes.Buffer{}, []string{"cleanup"})

	if code != exitNativeFailure {
		t.Fatalf("Run() code = %d, want %d", code, exitNativeFailure)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.OK {
		t.Fatal("response.OK = true, want fail-closed response")
	}
	if response.ErrorCode != "cleanup_failed" {
		t.Fatalf("response.ErrorCode = %q, want cleanup_failed", response.ErrorCode)
	}
}

func TestRunStartRejectsUnsupportedHelperCompatibility(t *testing.T) {
	var stdout bytes.Buffer
	request := StartRequest{
		ProtocolVersion:     ProtocolVersion,
		HelperCompatibility: "unknown-helper-secret",
		AttemptID:           "attempt-1",
		AttemptNonce:        "nonce-1",
		HostPID:             os.Getpid(),
		ExecutionPlan: clientcontrol.RuntimeExecutionPlan{
			HostAdapter: clientcontrol.RuntimeHostAdapterLinuxTun,
		},
		Lease: WireGuardTurnLease{
			TURNServerAddress: "turn.example.test:3478",
		},
		PolicyDirectives: NativePolicyDirectives{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		},
	}
	body, err := json.Marshal(request)
	if err != nil {
		t.Fatalf("marshal request: %v", err)
	}

	code := Run(bytes.NewReader(body), &stdout, &bytes.Buffer{}, []string{"start"})

	if code != exitInvalidRequest {
		t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "invalid_request" {
		t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
	}
	if strings.Contains(response.Message, "unknown-helper-secret") {
		t.Fatalf("response.Message leaked helper compatibility value: %q", response.Message)
	}
	if !strings.Contains(response.Message, HelperIdentity) {
		t.Fatalf("response.Message = %q, want helper identity detail", response.Message)
	}
}

func overrideStartNativeAttemptForTest(t *testing.T, fn func(io.Writer, StartRequest) int) func() {
	t.Helper()
	previous := startNativeAttempt
	startNativeAttempt = fn
	return func() {
		startNativeAttempt = previous
	}
}

func overrideCleanupNativeAttemptForTest(t *testing.T, fn func(io.Writer, AttemptRequest) int) func() {
	t.Helper()
	previous := cleanupNativeAttempt
	cleanupNativeAttempt = fn
	return func() {
		cleanupNativeAttempt = previous
	}
}

func TestRunStartRejectsOversizedPayload(t *testing.T) {
	var stdout bytes.Buffer
	body := strings.Repeat(" ", maxRequestBodyBytes+1)

	code := Run(strings.NewReader(body), &stdout, &bytes.Buffer{}, []string{"start"})

	if code != exitInvalidRequest {
		t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "invalid_request" {
		t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
	}
	if !strings.Contains(response.Message, "request exceeds") {
		t.Fatalf("response.Message = %q, want size-limit detail", response.Message)
	}
}

func TestRunStartRejectsProfileStorePathWithoutLeakingValue(t *testing.T) {
	var stdout bytes.Buffer
	request := `{
		"protocol_version": 1,
		"helper_compatibility": "relaydock-linux-tun-helper",
		"attempt_id": "attempt-1",
		"attempt_nonce": "nonce-1",
		"profile_store_path": "/var/lib/relaydock/vpn-transport-profiles/store.json",
		"execution_plan": {"host_adapter": "linux_tun"},
		"lease": {"turn_server_address": "turn.example.test:3478"},
		"policy_directives": {"underlay_route_policy": "preserve_active_local_network"}
	}`

	code := Run(strings.NewReader(request), &stdout, &bytes.Buffer{}, []string{"start"})

	if code != exitInvalidRequest {
		t.Fatalf("Run() code = %d, want %d", code, exitInvalidRequest)
	}
	response := decodeResponse(t, stdout.Bytes())
	if response.ErrorCode != "invalid_request" {
		t.Fatalf("response.ErrorCode = %q, want invalid_request", response.ErrorCode)
	}
	if strings.Contains(response.Message, "/var/lib/relaydock") {
		t.Fatalf("response.Message leaked profile-store path: %q", response.Message)
	}
	if !strings.Contains(response.Message, "unknown field") {
		t.Fatalf("response.Message = %q, want unknown field detail", response.Message)
	}
}

func TestErrorResponseForStartRedactsTransportSecrets(t *testing.T) {
	request := StartRequest{
		AttemptNonce: "attempt-nonce-secret",
		Lease: WireGuardTurnLease{
			TURNUsername:     "turn-user-secret",
			TURNPassword:     "turn-password-secret",
			ClientPrivateKey: "client-private-key-secret",
			PresharedKey:     "preshared-key-secret",
		},
	}
	response := errorResponse(
		"native_start_failed",
		errors.New("failed with attempt-nonce-secret turn-user-secret turn-password-secret client-private-key-secret preshared-key-secret /var/lib/relaydock/vpn-transport-profiles/store.json"),
		request.diagnosticSecrets()...,
	)

	body, err := json.Marshal(response)
	if err != nil {
		t.Fatalf("marshal response: %v", err)
	}
	text := string(body)
	for _, leaked := range []string{
		"attempt-nonce-secret",
		"turn-user-secret",
		"turn-password-secret",
		"client-private-key-secret",
		"preshared-key-secret",
		"/var/lib/relaydock",
	} {
		if strings.Contains(text, leaked) {
			t.Fatalf("response leaked %q: %s", leaked, text)
		}
	}
	for _, placeholder := range []string{
		redactedAttemptNonce,
		redactedTURNUsername,
		redactedTURNPassword,
		redactedWireGuardPrivateKey,
		redactedWireGuardPresharedKey,
		redactedProfileStorePath,
	} {
		if !strings.Contains(response.Message, placeholder) {
			t.Fatalf("response.Message = %q, want placeholder %s", response.Message, placeholder)
		}
	}
	if len(response.Diagnostics) != 1 || !response.Diagnostics[0].Redacted {
		t.Fatalf("response.Diagnostics = %#v, want one redacted diagnostic", response.Diagnostics)
	}
}

func decodeResponse(t *testing.T, body []byte) Response {
	t.Helper()
	var response Response
	if err := json.Unmarshal(body, &response); err != nil {
		t.Fatalf("decode response %q: %v", string(body), err)
	}
	return response
}

func validStartRequestForTest() StartRequest {
	return StartRequest{
		ProtocolVersion:     ProtocolVersion,
		HelperCompatibility: HelperIdentity,
		AttemptID:           "attempt-1",
		AttemptNonce:        "nonce-1",
		HostPID:             os.Getpid(),
		ExecutionPlan: clientcontrol.RuntimeExecutionPlan{
			AccessMethod:  clientcontrol.RuntimeAccessMethodTURNCredentials,
			CarrierFamily: clientcontrol.RuntimeCarrierFamilyTURNDatagram,
			EngineFamily:  clientcontrol.RuntimeEngineFamilyWireGuardNative,
			HostAdapter:   clientcontrol.RuntimeHostAdapterLinuxTun,
		},
		Lease: WireGuardTurnLease{
			TURNServerAddress: "turn.example.test:3478",
			TURNUsername:      "turn-user-secret",
			TURNPassword:      "turn-password-secret",
			ClientPrivateKey:  "client-private-key-secret",
			ClientAddresses:   []string{"10.10.0.2/32"},
			PresharedKey:      "preshared-key-secret",
			AllowedIPs:        []string{"10.10.0.1/32"},
			DNSServers:        []string{"1.1.1.1"},
		},
		PolicyDirectives: NativePolicyDirectives{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			UnderlayExclusions:  []string{"turn.example.test", "203.0.113.0/24"},
			DNSBypassRequired:   true,
		},
	}
}
