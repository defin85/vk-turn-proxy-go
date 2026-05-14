package linuxdesktophost

import (
	"context"
	"errors"
	"log/slog"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/linuxtunhelper"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestNewLinuxTunNativeClientForPackagedUbuntuUsesHelper(t *testing.T) {
	t.Setenv(linuxTunPackagedTargetEnv, linuxTunPackagedTargetUbuntu)
	t.Setenv(linuxTunHelperPathEnv, "/tmp/relaydock-linux-tun-helper")

	native := newLinuxTunNativeClientForHost(slog.Default())

	helper, ok := native.(linuxTunHelperNativeClient)
	if !ok {
		t.Fatalf("native client = %T, want linuxTunHelperNativeClient", native)
	}
	if helper.helperPath != "/tmp/relaydock-linux-tun-helper" {
		t.Fatalf("helperPath = %q, want override", helper.helperPath)
	}
}

func TestLinuxTunHelperNativeClientBuildsAttemptScopedStartPayload(t *testing.T) {
	restore := overrideLinuxTunHelperStartCommandForTest(t, func(
		_ context.Context,
		helperPath string,
		request linuxtunhelper.StartRequest,
	) (linuxtunhelper.Response, error) {
		if helperPath != "/opt/test-helper" {
			t.Fatalf("helperPath = %q, want /opt/test-helper", helperPath)
		}
		if request.AttemptID != "attempt-1" || request.AttemptNonce != "nonce-1" {
			t.Fatalf("attempt = %q/%q, want attempt-1/nonce-1", request.AttemptID, request.AttemptNonce)
		}
		if request.HostPID <= 0 {
			t.Fatalf("host_pid = %d, want current clientd pid", request.HostPID)
		}
		if request.ExecutionPlan.HostAdapter != clientcontrol.RuntimeHostAdapterLinuxTun {
			t.Fatalf("host_adapter = %q, want linux_tun", request.ExecutionPlan.HostAdapter)
		}
		if request.Lease.TURNServerAddress != "turn.example.test:3478" {
			t.Fatalf("turn_server_address = %q, want materialized lease", request.Lease.TURNServerAddress)
		}
		if request.PolicyDirectives.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
			t.Fatalf("underlay policy = %q, want preserve_active_local_network", request.PolicyDirectives.UnderlayRoutePolicy)
		}
		return linuxtunhelper.Response{
			ProtocolVersion: linuxtunhelper.ProtocolVersion,
			HelperIdentity:  linuxtunhelper.HelperIdentity,
			OK:              false,
			ErrorCode:       "native_start_not_implemented",
			Message:         "native startup is not wired yet",
		}, nil
	})
	defer restore()

	native := linuxTunHelperNativeClient{helperPath: "/opt/test-helper"}
	_, err := native.Start(context.Background(), LinuxTunNativeStartRequest{
		AttemptID:    "attempt-1",
		AttemptNonce: "nonce-1",
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ExecutionPlan: clientcontrol.RuntimeExecutionPlan{
			HostAdapter: clientcontrol.RuntimeHostAdapterLinuxTun,
		},
		Lease: clientcontrol.WireGuardTurnExecutionLease{
			ResolutionID:      "resolution-secret",
			TURNServerAddress: "turn.example.test:3478",
		},
		PolicyDirectives: LinuxNativePolicyDirectives{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			UnderlayExclusions:  []string{"turn.example.test:3478"},
			DNSBypassRequired:   true,
		},
	})

	if err == nil {
		t.Fatal("Start() error = nil, want native failure")
	}
	var failure *LinuxTunNativeFailure
	if !errors.As(err, &failure) {
		t.Fatalf("Start() error = %v, want LinuxTunNativeFailure", err)
	}
	if failure.Kind != LinuxTunNativeFailureNativeStart {
		t.Fatalf("failure.Kind = %q, want native_start", failure.Kind)
	}
}

func TestLinuxTunHelperNativeClientMapsReadyResponse(t *testing.T) {
	restore := overrideLinuxTunHelperStartCommandForTest(t, func(
		context.Context,
		string,
		linuxtunhelper.StartRequest,
	) (linuxtunhelper.Response, error) {
		return linuxtunhelper.Response{
			ProtocolVersion:     linuxtunhelper.ProtocolVersion,
			HelperIdentity:      linuxtunhelper.HelperIdentity,
			OK:                  true,
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
			UnderlayExclusions:  []string{"203.0.113.10"},
			Dataplane: &clientcontrol.PlatformTunnelDataplaneEvidence{
				HostAttached:                 true,
				WireGuardHandshakeFresh:      true,
				WireGuardRxBytesDelta:        10,
				WireGuardTxBytesDelta:        20,
				BidirectionalTrafficVerified: true,
			},
		}, nil
	})
	defer restore()

	native := linuxTunHelperNativeClient{helperPath: "/opt/test-helper"}
	result, err := native.Start(context.Background(), LinuxTunNativeStartRequest{
		AttemptID:    "attempt-1",
		AttemptNonce: "nonce-1",
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
		ExecutionPlan: clientcontrol.RuntimeExecutionPlan{
			HostAdapter: clientcontrol.RuntimeHostAdapterLinuxTun,
		},
		Lease: clientcontrol.WireGuardTurnExecutionLease{
			TURNServerAddress: "turn.example.test:3478",
		},
		PolicyDirectives: LinuxNativePolicyDirectives{
			UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		},
	})
	if err != nil {
		t.Fatalf("Start() error = %v", err)
	}
	if result.Dataplane == nil || !result.Dataplane.BidirectionalTrafficVerified {
		t.Fatalf("Start().Dataplane = %+v, want ready dataplane", result.Dataplane)
	}
	if len(result.UnderlayExclusions) != 1 || result.UnderlayExclusions[0] != "203.0.113.10" {
		t.Fatalf("Start().UnderlayExclusions = %v, want helper exclusions", result.UnderlayExclusions)
	}
}

func TestLinuxTunHelperNativeClientMapsCleanupFailure(t *testing.T) {
	restore := overrideLinuxTunHelperCommandForTest(t, func(
		_ context.Context,
		_ string,
		command linuxtunhelper.Command,
		payload any,
	) (linuxtunhelper.Response, error) {
		if command != linuxtunhelper.CommandCleanup {
			t.Fatalf("command = %q, want cleanup", command)
		}
		request, ok := payload.(linuxtunhelper.AttemptRequest)
		if !ok {
			t.Fatalf("payload = %T, want linuxtunhelper.AttemptRequest", payload)
		}
		if request.AttemptID != "attempt-1" || request.AttemptNonce != "nonce-1" {
			t.Fatalf("attempt = %q/%q, want attempt-1/nonce-1", request.AttemptID, request.AttemptNonce)
		}
		return linuxtunhelper.Response{
			ProtocolVersion: linuxtunhelper.ProtocolVersion,
			HelperIdentity:  linuxtunhelper.HelperIdentity,
			OK:              false,
			ErrorCode:       "cleanup_failed",
			Message:         "helper cleanup failed",
		}, nil
	})
	defer restore()

	native := linuxTunHelperNativeClient{helperPath: "/opt/test-helper"}
	err := native.Cleanup(context.Background(), LinuxTunNativeCleanupRequest{
		AttemptID:    "attempt-1",
		AttemptNonce: "nonce-1",
		Mode:         clientcontrol.PlatformTunnelModeLinuxTun,
	})

	if err == nil {
		t.Fatal("Cleanup() error = nil, want cleanup failure")
	}
	var failure *LinuxTunNativeFailure
	if !errors.As(err, &failure) {
		t.Fatalf("Cleanup() error = %v, want LinuxTunNativeFailure", err)
	}
	if failure.Kind != LinuxTunNativeFailureCleanup {
		t.Fatalf("failure.Kind = %q, want cleanup", failure.Kind)
	}
}

func TestLinuxTunHelperExitFailureKindClassifiesAuthFailuresAsPermission(t *testing.T) {
	messages := []string{
		"Error creating textual authentication agent: Error opening current controlling terminal for the process (`/dev/tty'): No such device or address",
		"Not authorized",
		"pkexec must be setuid root",
		"polkit authentication failed",
	}
	for _, message := range messages {
		if got := linuxTunHelperExitFailureKind(message); got != LinuxTunNativeFailurePermissionDenied {
			t.Fatalf("linuxTunHelperExitFailureKind(%q) = %q, want %q", message, got, LinuxTunNativeFailurePermissionDenied)
		}
	}
}

func TestLinuxTunHelperExitFailureKindKeepsHelperFailuresSeparate(t *testing.T) {
	message := "helper response contains invalid JSON"
	if got := linuxTunHelperExitFailureKind(message); got != LinuxTunNativeFailureHelperExit {
		t.Fatalf("linuxTunHelperExitFailureKind(%q) = %q, want %q", message, got, LinuxTunNativeFailureHelperExit)
	}
}

func overrideLinuxTunHelperCommandForTest(
	t *testing.T,
	fn func(context.Context, string, linuxtunhelper.Command, any) (linuxtunhelper.Response, error),
) func() {
	t.Helper()
	previous := runLinuxTunHelperCommand
	runLinuxTunHelperCommand = fn
	return func() {
		runLinuxTunHelperCommand = previous
	}
}

func overrideLinuxTunHelperStartCommandForTest(
	t *testing.T,
	fn func(context.Context, string, linuxtunhelper.StartRequest) (linuxtunhelper.Response, error),
) func() {
	t.Helper()
	previous := startLinuxTunHelperCommand
	startLinuxTunHelperCommand = fn
	return func() {
		startLinuxTunHelperCommand = previous
	}
}
