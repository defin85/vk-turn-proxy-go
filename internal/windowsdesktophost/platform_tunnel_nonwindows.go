//go:build !windows

package windowsdesktophost

import (
	"log/slog"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func newWindowsWintunLifecycle(*slog.Logger) WindowsWintunLifecycle {
	return nil
}

func currentWindowsWintunCapability(build clientcontrol.BuildIdentity) clientcontrol.PlatformTunnelCapability {
	return defaultWindowsWintunCapability(build)
}
