package linuxdesktophost

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"os"
	"os/exec"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/linuxtunhelper"
)

const (
	linuxTunHelperPathEnv     = "VKTP_LINUX_TUN_HELPER"
	defaultLinuxTunHelperPath = "/opt/relaydock/libexec/relaydock-linux-tun-helper"
)

var runLinuxTunHelperCommand = defaultRunLinuxTunHelperCommand
var startLinuxTunHelperCommand = defaultStartLinuxTunHelperCommand

type linuxTunHelperNativeClient struct {
	helperPath string
	logger     *slog.Logger
}

func newLinuxTunNativeClientForHost(logger *slog.Logger) LinuxTunNativeClient {
	if os.Getenv(linuxTunPackagedTargetEnv) == linuxTunPackagedTargetUbuntu {
		return linuxTunHelperNativeClient{
			helperPath: detectLinuxTunHelperPath(),
			logger:     logger,
		}
	}
	return linuxTunLifecycleNativeClient{lifecycle: newLinuxTunLifecycleForHost(logger)}
}

func detectLinuxTunHelperPath() string {
	if override := strings.TrimSpace(os.Getenv(linuxTunHelperPathEnv)); override != "" {
		return override
	}
	return defaultLinuxTunHelperPath
}

func (c linuxTunHelperNativeClient) Start(
	ctx context.Context,
	req LinuxTunNativeStartRequest,
) (LinuxTunNativeStartResult, error) {
	response, err := startLinuxTunHelperCommand(ctx, c.helperPath, linuxtunhelper.StartRequest{
		ProtocolVersion:     linuxtunhelper.ProtocolVersion,
		HelperCompatibility: linuxtunhelper.HelperIdentity,
		AttemptID:           req.AttemptID,
		AttemptNonce:        req.AttemptNonce,
		HostPID:             os.Getpid(),
		ExecutionPlan:       req.ExecutionPlan,
		Lease:               linuxtunhelper.NewWireGuardTurnLease(req.Lease),
		PolicyDirectives: linuxtunhelper.NativePolicyDirectives{
			UnderlayRoutePolicy: req.PolicyDirectives.UnderlayRoutePolicy,
			UnderlayExclusions:  append([]string(nil), req.PolicyDirectives.UnderlayExclusions...),
			DNSBypassRequired:   req.PolicyDirectives.DNSBypassRequired,
		},
	})
	if err != nil {
		return LinuxTunNativeStartResult{}, err
	}
	if response.OK {
		if response.Dataplane == nil {
			return LinuxTunNativeStartResult{}, &LinuxTunNativeFailure{
				Kind:    LinuxTunNativeFailureNativeStart,
				Message: "linux_tun helper returned success without native dataplane evidence",
			}
		}
		return LinuxTunNativeStartResult{
			UnderlayRoutePolicy: response.UnderlayRoutePolicy,
			UnderlayExclusions:  append([]string(nil), response.UnderlayExclusions...),
			Dataplane:           response.Dataplane,
		}, nil
	}
	return LinuxTunNativeStartResult{}, linuxTunNativeFailureFromHelperResponse(response)
}

func (c linuxTunHelperNativeClient) Cleanup(ctx context.Context, req LinuxTunNativeCleanupRequest) error {
	response, err := runLinuxTunHelperCommand(ctx, c.helperPath, linuxtunhelper.CommandCleanup, linuxtunhelper.AttemptRequest{
		ProtocolVersion: linuxtunhelper.ProtocolVersion,
		AttemptID:       req.AttemptID,
		AttemptNonce:    req.AttemptNonce,
	})
	if err != nil {
		return err
	}
	if response.OK {
		return nil
	}
	return linuxTunNativeFailureFromHelperResponse(response)
}

func linuxTunNativeFailureFromHelperResponse(response linuxtunhelper.Response) error {
	code := strings.TrimSpace(response.ErrorCode)
	message := strings.TrimSpace(response.Message)
	if message == "" {
		message = code
	}
	kind := LinuxTunNativeFailureNativeStart
	switch code {
	case "permission_denied", "authorization_denied":
		kind = LinuxTunNativeFailurePermissionDenied
	case "invalid_request", "usage":
		kind = LinuxTunNativeFailureMalformedPayload
	case "helper_exit":
		kind = LinuxTunNativeFailureHelperExit
	case "native_start_not_implemented", "native_start_failed":
		kind = LinuxTunNativeFailureNativeStart
	case "route_validate_failed":
		kind = LinuxTunNativeFailureRouteValidate
	case "runtime_attach_failed":
		kind = LinuxTunNativeFailureRuntimeAttach
	case "dataplane_failed":
		kind = LinuxTunNativeFailureDataplane
	case "cleanup_not_implemented", "cleanup_failed":
		kind = LinuxTunNativeFailureCleanup
	case "stale_native_state":
		kind = LinuxTunNativeFailureStaleState
	}
	return &LinuxTunNativeFailure{
		Kind:         kind,
		Message:      message,
		Stage:        response.Stage,
		Prerequisite: response.MissingPrerequisite,
	}
}

func defaultStartLinuxTunHelperCommand(
	ctx context.Context,
	helperPath string,
	payload linuxtunhelper.StartRequest,
) (linuxtunhelper.Response, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    LinuxTunNativeFailureMalformedPayload,
			Message: fmt.Sprintf("marshal linux_tun helper payload: %v", err),
		}
	}
	cmd := exec.Command("pkexec", strings.TrimSpace(helperPath), string(linuxtunhelper.CommandStart))
	stdin, err := cmd.StdinPipe()
	if err != nil {
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    LinuxTunNativeFailureHelperExit,
			Message: fmt.Sprintf("open linux_tun helper stdin: %v", err),
		}
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    LinuxTunNativeFailureHelperExit,
			Message: fmt.Sprintf("open linux_tun helper stdout: %v", err),
		}
	}
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Start(); err != nil {
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    linuxTunHelperExitFailureKind(err.Error()),
			Message: err.Error(),
		}
	}
	if _, err := stdin.Write(body); err != nil {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    LinuxTunNativeFailureHelperExit,
			Message: fmt.Sprintf("write linux_tun helper payload: %v", err),
		}
	}
	if err := stdin.Close(); err != nil {
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    LinuxTunNativeFailureHelperExit,
			Message: fmt.Sprintf("close linux_tun helper stdin: %v", err),
		}
	}

	type decodeResult struct {
		response linuxtunhelper.Response
		err      error
	}
	decoded := make(chan decodeResult, 1)
	go func() {
		decoder := json.NewDecoder(stdout)
		var response linuxtunhelper.Response
		err := decoder.Decode(&response)
		decoded <- decodeResult{response: response, err: err}
	}()

	select {
	case <-ctx.Done():
		_ = cmd.Process.Kill()
		_ = cmd.Wait()
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    LinuxTunNativeFailureHelperExit,
			Message: ctx.Err().Error(),
		}
	case result := <-decoded:
		if result.err != nil {
			waitErr := cmd.Wait()
			message := strings.TrimSpace(stderr.String())
			if message == "" && waitErr != nil {
				message = waitErr.Error()
			}
			if message == "" {
				message = result.err.Error()
			}
			return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
				Kind:    linuxTunHelperExitFailureKind(message),
				Message: message,
			}
		}
		if result.response.OK {
			go func() {
				_ = cmd.Wait()
			}()
			return result.response, nil
		}
		_ = cmd.Wait()
		return result.response, nil
	}
}

func defaultRunLinuxTunHelperCommand(
	ctx context.Context,
	helperPath string,
	command linuxtunhelper.Command,
	payload any,
) (linuxtunhelper.Response, error) {
	body, err := json.Marshal(payload)
	if err != nil {
		return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
			Kind:    LinuxTunNativeFailureMalformedPayload,
			Message: fmt.Sprintf("marshal linux_tun helper payload: %v", err),
		}
	}
	cmd := exec.CommandContext(ctx, "pkexec", strings.TrimSpace(helperPath), string(command))
	cmd.Stdin = bytes.NewReader(body)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	stdout, runErr := cmd.Output()
	response, decodeErr := decodeLinuxTunHelperResponse(stdout)
	if decodeErr == nil {
		return response, nil
	}
	message := strings.TrimSpace(stderr.String())
	if message == "" && runErr != nil {
		message = runErr.Error()
	}
	if message == "" {
		message = decodeErr.Error()
	}
	return linuxtunhelper.Response{}, &LinuxTunNativeFailure{
		Kind:    linuxTunHelperExitFailureKind(message),
		Message: message,
	}
}

func linuxTunHelperExitFailureKind(message string) LinuxTunNativeFailureKind {
	normalized := strings.ToLower(strings.TrimSpace(message))
	for _, fragment := range []string{
		"authentication agent",
		"not authorized",
		"authorization",
		"permission denied",
		"polkit",
		"pkexec",
	} {
		if strings.Contains(normalized, fragment) {
			return LinuxTunNativeFailurePermissionDenied
		}
	}
	return LinuxTunNativeFailureHelperExit
}

func decodeLinuxTunHelperResponse(body []byte) (linuxtunhelper.Response, error) {
	decoder := json.NewDecoder(bytes.NewReader(body))
	var response linuxtunhelper.Response
	if err := decoder.Decode(&response); err != nil {
		return linuxtunhelper.Response{}, err
	}
	var extra struct{}
	if err := decoder.Decode(&extra); err != io.EOF {
		return linuxtunhelper.Response{}, fmt.Errorf("helper response contains extra JSON values")
	}
	return response, nil
}
