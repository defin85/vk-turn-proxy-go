package linuxdesktophost

import (
	"io"
	"log/slog"

	"github.com/defin85/vk-turn-proxy-go/internal/buildinfo"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func NewClientControlHost(logger *slog.Logger) *clientcontrol.Host {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelInfo}))
	}
	build := currentBuildIdentity()
	controller := newLinuxTunController(currentLinuxTunCapability(build), nil)
	return clientcontrol.New(
		clientcontrol.WithLogger(logger),
		clientcontrol.WithBuildIdentity(build),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
	)
}

func currentBuildIdentity() clientcontrol.BuildIdentity {
	identity := buildinfo.Current(buildinfo.Options{
		Role: "clientd",
	})
	return clientcontrol.BuildIdentity{
		Product:     identity.Product,
		Version:     identity.Version,
		BuildNumber: identity.BuildNumber,
		Revision:    identity.Revision,
		Dirty:       identity.Dirty,
		BuiltAt:     identity.BuiltAt,
		Role:        identity.Role,
		Target:      identity.Target,
	}
}
