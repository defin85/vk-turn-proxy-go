//go:build !linux

package linuxdesktophost

import (
	"fmt"
	"log/slog"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func defaultLinuxTunPrerequisiteCheck(build clientcontrol.BuildIdentity) *linuxTunPrerequisiteFailure {
	return &linuxTunPrerequisiteFailure{
		prerequisite: clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		message: fmt.Sprintf(
			"The %s host cannot run linux_tun outside Linux.",
			hostTargetLabel(build),
		),
	}
}

func newLinuxTunLifecycle(_ *slog.Logger) LinuxTunLifecycle {
	return nil
}
