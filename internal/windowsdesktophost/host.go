package windowsdesktophost

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/buildinfo"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

const windowsTransportProfileStoreEnv = "VKTP_WINDOWS_TRANSPORT_PROFILE_STORE"

func NewClientControlHost(logger *slog.Logger) *clientcontrol.Host {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelInfo}))
	}
	build := currentBuildIdentity()
	materializer, materializerErr := defaultWindowsWireGuardTurnMaterializer()
	storePath, storePathErr := detectWindowsTransportProfileStorePath()
	if storePathErr != nil {
		logger.Warn(
			"windows transport profile store path unavailable; enabling in-memory store fallback",
			"error",
			storePathErr,
		)
	}
	controller := newWindowsWintunController(
		currentWindowsWintunCapability(build, nil),
		newWindowsWintunLifecycle(logger),
	)
	opts := []clientcontrol.Option{
		clientcontrol.WithLogger(logger),
		clientcontrol.WithBuildIdentity(build),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{controller.Capability()}),
		clientcontrol.WithPlatformTunnelStarter(controller.Start),
		clientcontrol.WithPlatformTunnelStopper(controller.Stop),
	}
	if strings.TrimSpace(storePath) != "" {
		opts = append(opts, clientcontrol.WithVPNTransportProfileStorePath(storePath))
	} else {
		opts = append(opts, clientcontrol.WithVPNTransportProfileStore())
	}
	if materializer != nil {
		opts = append(opts, clientcontrol.WithWireGuardTurnMaterializer(materializer))
	} else if materializerErr != nil {
		logger.Warn(
			"windows_wintun legacy WireGuard profile path unavailable; startup now depends on imported transport profiles",
			"error",
			materializerErr,
		)
	}
	host := clientcontrol.New(opts...)
	migrateLegacyWindowsWireGuardProfile(logger, host)
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

func detectWindowsTransportProfileStorePath() (string, error) {
	if override := strings.TrimSpace(os.Getenv(windowsTransportProfileStoreEnv)); override != "" {
		return override, nil
	}
	configDir, err := os.UserConfigDir()
	if err == nil && strings.TrimSpace(configDir) != "" {
		return filepath.Join(configDir, "vk-turn-proxy-go", "vpn-transport-profiles", "store.json"), nil
	}
	home, homeErr := os.UserHomeDir()
	if homeErr != nil || strings.TrimSpace(home) == "" {
		if err != nil {
			return "", fmt.Errorf("locate Windows config directory: %w", err)
		}
		return "", fmt.Errorf("locate Windows home directory: %w", homeErr)
	}
	return filepath.Join(home, ".vk-turn-proxy-go", "vpn-transport-profiles", "store.json"), nil
}

func migrateLegacyWindowsWireGuardProfile(logger *slog.Logger, host *clientcontrol.Host) {
	if host == nil {
		return
	}
	legacyPath, err := detectWindowsWireGuardProfilePath()
	if err != nil {
		return
	}
	if _, _, err := host.MigrateWireGuardTransportProfileFromPath(legacyPath); err != nil && logger != nil {
		logger.Warn("legacy Windows WireGuard profile migration failed", "error", err)
	}
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
