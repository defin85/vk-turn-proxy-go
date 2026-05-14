//go:build !linux

package linuxtunhelper

import (
	"errors"
	"io"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func defaultStartNativeAttempt(stdout io.Writer, req StartRequest) int {
	writeResponse(stdout, errorResponseWithStage(
		"native_start_not_implemented",
		clientcontrol.PlatformTunnelStartupStageHostBringup,
		clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		errors.New("linux_tun helper native startup is only implemented on Linux"),
		req.diagnosticSecrets()...,
	))
	return exitNotImplemented
}

func defaultStatusNativeAttempt(stdout io.Writer, req AttemptRequest) int {
	writeResponse(stdout, errorResponse("status_not_implemented", errors.New("linux_tun helper status is only implemented on Linux"), req.diagnosticSecrets()...))
	return exitNotImplemented
}

func defaultCleanupNativeAttempt(stdout io.Writer, req AttemptRequest) int {
	writeResponse(stdout, errorResponse("cleanup_not_implemented", errors.New("linux_tun helper cleanup is only implemented on Linux"), req.diagnosticSecrets()...))
	return exitNotImplemented
}
