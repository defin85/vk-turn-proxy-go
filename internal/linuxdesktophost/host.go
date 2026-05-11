package linuxdesktophost

import (
	"context"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"os"
	"path/filepath"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/buildinfo"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

const linuxTransportProfileStoreEnv = "VKTP_LINUX_TRANSPORT_PROFILE_STORE"

var (
	errMissingExecutionPlan   = errors.New("linux_tun startup requires an execution plan")
	errMissingResolutionID    = errors.New("linux_tun startup requires resolution_id")
	errMissingRuntimeDefaults = errors.New("linux_tun startup requires runtime_defaults")
)

func NewClientControlHost(logger *slog.Logger) *clientcontrol.Host {
	if logger == nil {
		logger = slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelInfo}))
	}
	build := currentBuildIdentity()
	controller := newLinuxTunController(currentLinuxTunCapability(build), newLinuxTunLifecycleForHost(logger))
	storePath, storePathErr := detectLinuxTransportProfileStorePath()
	if storePathErr != nil {
		logger.Warn(
			"linux transport profile store path unavailable; enabling in-memory store fallback",
			"error",
			storePathErr,
		)
	}
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
	host := clientcontrol.New(opts...)
	attachLinuxWireGuardTurnLeaseProvider(controller, host)
	return host
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

func detectLinuxTransportProfileStorePath() (string, error) {
	if override := strings.TrimSpace(os.Getenv(linuxTransportProfileStoreEnv)); override != "" {
		return override, nil
	}
	configDir, err := os.UserConfigDir()
	if err == nil && strings.TrimSpace(configDir) != "" {
		return filepath.Join(configDir, "vk-turn-proxy-go", "vpn-transport-profiles", "store.json"), nil
	}
	home, homeErr := os.UserHomeDir()
	if homeErr != nil || strings.TrimSpace(home) == "" {
		if err != nil {
			return "", fmt.Errorf("locate Linux config directory: %w", err)
		}
		return "", fmt.Errorf("locate Linux home directory: %w", homeErr)
	}
	return filepath.Join(home, ".vk-turn-proxy-go", "vpn-transport-profiles", "store.json"), nil
}

func attachLinuxWireGuardTurnLeaseProvider(controller *linuxTunController, host *clientcontrol.Host) {
	if controller == nil || host == nil {
		return
	}
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
			return host.MaterializeWireGuardTurnExecutionLeaseForProfile(
				ctx,
				req.ResolutionID,
				*req.RuntimeDefaults,
				plan,
				req.TransportProfile,
			)
		},
	)
}
