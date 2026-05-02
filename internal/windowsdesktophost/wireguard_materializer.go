package windowsdesktophost

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardprofile"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

const windowsWireGuardProfileEnv = "VKTP_WINDOWS_WIREGUARD_PROFILE"

func defaultWindowsWireGuardTurnMaterializer() (clientcontrol.WireGuardTurnMaterializer, error) {
	if _, _, err := loadWindowsWireGuardProfile(); err != nil {
		return nil, err
	}
	return func(
		_ context.Context,
		req clientcontrol.WireGuardTurnMaterializeRequest,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		_, profile, err := loadWindowsWireGuardProfile()
		if err != nil {
			return nil, err
		}
		turnServerAddress := strings.TrimSpace(req.Defaults.TURNServer)
		if turnServerAddress == "" {
			turnServerAddress = strings.TrimSpace(req.Credentials.Address)
		}
		if turnServerAddress == "" {
			return nil, fmt.Errorf("strict Windows WireGuard materializer requires a TURN server address")
		}
		peerEndpointAddress := strings.TrimSpace(profile.Endpoint)
		if peerEndpointAddress == "" {
			return nil, fmt.Errorf("strict Windows WireGuard materializer requires an explicit raw WireGuard ingress endpoint in the WireGuard profile")
		}
		var expiresAt *time.Time
		if req.Credentials.TTL > 0 {
			value := time.Now().UTC().Add(req.Credentials.TTL)
			expiresAt = &value
		}
		return &clientcontrol.WireGuardTurnExecutionLease{
			ResolutionID:               req.ResolutionID,
			AccessMethod:               req.Descriptor.Plan.AccessMethod,
			CarrierFamily:              req.Descriptor.Plan.CarrierFamily,
			EngineFamily:               req.Descriptor.Plan.EngineFamily,
			RemoteEndpointFamily:       req.Descriptor.RemoteEndpointFamily,
			RemoteEndpointRole:         req.Descriptor.RemoteEndpointRole,
			TURNServerAddress:          turnServerAddress,
			TURNUsername:               strings.TrimSpace(req.Credentials.Username),
			TURNPassword:               strings.TrimSpace(req.Credentials.Password),
			PeerEndpointAddress:        peerEndpointAddress,
			ClientPrivateKey:           profile.PrivateKey,
			ClientAddresses:            append([]string(nil), profile.Addresses...),
			PeerPublicKey:              profile.PeerPublicKey,
			PresharedKey:               profile.PresharedKey,
			AllowedIPs:                 append([]string(nil), profile.AllowedIPs...),
			DNSServers:                 append([]string(nil), profile.DNSServers...),
			MTU:                        profile.MTU,
			PersistentKeepaliveSeconds: profile.PersistentKeepaliveSeconds,
			ExpiresAt:                  expiresAt,
		}, nil
	}, nil
}

func loadWindowsWireGuardProfile() (string, *wireguardprofile.Profile, error) {
	profilePath, err := detectWindowsWireGuardProfilePath()
	if err != nil {
		return "", nil, err
	}
	profile, err := wireguardprofile.Load(profilePath)
	if err != nil {
		return "", nil, err
	}
	return profilePath, profile, nil
}

func detectWindowsWireGuardProfilePath() (string, error) {
	if override := strings.TrimSpace(os.Getenv(windowsWireGuardProfileEnv)); override != "" {
		if wireguardprofile.FileExists(override) {
			return override, nil
		}
		return "", fmt.Errorf("Windows WireGuard profile %s does not exist", override)
	}
	home, err := os.UserHomeDir()
	if err != nil {
		return "", fmt.Errorf("locate Windows home directory: %w", err)
	}
	defaultPath := filepath.Join(home, ".local", "state", "vk-turn-proxy-go", "wg", "desktop1-windows.conf")
	if wireguardprofile.FileExists(defaultPath) {
		return defaultPath, nil
	}
	return "", fmt.Errorf("Windows WireGuard profile %s does not exist", defaultPath)
}
