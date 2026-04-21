package windowsdesktophost

import (
	"context"
	"io"
	"log/slog"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/buildinfo"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func NewClientControlHost(logger *slog.Logger) *clientcontrol.Host {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelInfo}))
	}
	build := currentBuildIdentity()
	materializer := defaultWindowsWireGuardTurnMaterializer()
	controller := newWindowsWintunController(currentWindowsWintunCapability(build), newWindowsWintunLifecycle(logger))
	opts := []clientcontrol.Option{
		clientcontrol.WithLogger(logger),
		clientcontrol.WithBuildIdentity(build),
		clientcontrol.WithWireGuardTurnMaterializer(materializer),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
	}
	host := clientcontrol.New(opts...)
	controller.setWireGuardTurnLeaseProvider(
		func(
			ctx context.Context,
			req clientcontrol.PlatformTunnelStartRequest,
			plan *clientcontrol.RuntimeExecutionPlan,
		) (*clientcontrol.WireGuardTurnExecutionLease, error) {
			if plan == nil {
				return nil, errMissingExecutionPlan
			}
			if strings.TrimSpace(req.ResolutionID) == "" {
				return nil, errMissingResolutionID
			}
			if req.RuntimeDefaults == nil {
				return nil, errMissingRuntimeDefaults
			}
			return host.MaterializeWireGuardTurnExecutionLease(
				ctx,
				req.ResolutionID,
				*req.RuntimeDefaults,
				plan,
			)
		},
	)
	return host
}

func currentBuildIdentity() clientcontrol.BuildIdentity {
	identity := buildinfo.Current(buildinfo.Options{
		Role:   "clientd",
		Target: "windows/amd64",
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
