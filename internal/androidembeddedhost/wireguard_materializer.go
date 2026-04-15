package androidembeddedhost

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

const androidWireGuardProfileEnv = "VKTP_ANDROID_WIREGUARD_PROFILE"

var (
	androidWireGuardProfilePathMu sync.RWMutex
	androidWireGuardProfilePath   string
)

type wireGuardProfile struct {
	privateKey string
	addresses  []string
	dnsServers []string
	mtu        int

	peerPublicKey string
	allowedIPs    []string
	endpoint      string
}

func defaultAndroidWireGuardTurnMaterializer() clientcontrol.WireGuardTurnMaterializer {
	profilePath, ok := detectAndroidWireGuardProfilePath()
	if !ok {
		return nil
	}
	return func(
		_ context.Context,
		req clientcontrol.WireGuardTurnMaterializeRequest,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		profile, err := loadWireGuardProfile(profilePath)
		if err != nil {
			return nil, err
		}
		turnServerAddress := strings.TrimSpace(req.Defaults.TURNServer)
		if turnServerAddress == "" {
			turnServerAddress = strings.TrimSpace(req.Credentials.Address)
		}
		if turnServerAddress == "" {
			return nil, fmt.Errorf("strict Android WireGuard materializer requires a TURN server address")
		}
		peerEndpointAddress := strings.TrimSpace(req.Defaults.PeerAddr)
		if peerEndpointAddress == "" {
			peerEndpointAddress = strings.TrimSpace(profile.endpoint)
		}
		if peerEndpointAddress == "" {
			return nil, fmt.Errorf("strict Android WireGuard materializer requires a peer endpoint address")
		}
		var expiresAt *time.Time
		if req.Credentials.TTL > 0 {
			value := time.Now().UTC().Add(req.Credentials.TTL)
			expiresAt = &value
		}
		return &clientcontrol.WireGuardTurnExecutionLease{
			ResolutionID:         req.ResolutionID,
			AccessMethod:         req.Descriptor.Plan.AccessMethod,
			CarrierFamily:        req.Descriptor.Plan.CarrierFamily,
			EngineFamily:         req.Descriptor.Plan.EngineFamily,
			RemoteEndpointFamily: req.Descriptor.RemoteEndpointFamily,
			RemoteEndpointRole:   clientcontrol.WireGuardTurnRemoteEndpointRoleDatagramTermination,
			TURNServerAddress:    turnServerAddress,
			TURNUsername:         strings.TrimSpace(req.Credentials.Username),
			TURNPassword:         strings.TrimSpace(req.Credentials.Password),
			PeerEndpointAddress:  peerEndpointAddress,
			ClientPrivateKey:     profile.privateKey,
			ClientAddresses:      append([]string(nil), profile.addresses...),
			PeerPublicKey:        profile.peerPublicKey,
			AllowedIPs:           append([]string(nil), profile.allowedIPs...),
			DNSServers:           append([]string(nil), profile.dnsServers...),
			MTU:                  profile.mtu,
			ExpiresAt:            expiresAt,
		}, nil
	}
}

func SetAndroidWireGuardProfilePath(path string) {
	androidWireGuardProfilePathMu.Lock()
	androidWireGuardProfilePath = strings.TrimSpace(path)
	androidWireGuardProfilePathMu.Unlock()
}

func detectAndroidWireGuardProfilePath() (string, bool) {
	androidWireGuardProfilePathMu.RLock()
	overridePath := androidWireGuardProfilePath
	androidWireGuardProfilePathMu.RUnlock()
	if override := strings.TrimSpace(overridePath); override != "" {
		if fileExists(override) {
			return override, true
		}
		return "", false
	}
	if override := strings.TrimSpace(os.Getenv(androidWireGuardProfileEnv)); override != "" {
		if fileExists(override) {
			return override, true
		}
		return "", false
	}
	return "", false
}

func fileExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && !info.IsDir()
}

func loadWireGuardProfile(path string) (*wireGuardProfile, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read Android WireGuard profile: %w", err)
	}
	profile := &wireGuardProfile{mtu: 1280}
	section := ""
	for _, rawLine := range strings.Split(string(data), "\n") {
		line := strings.TrimSpace(rawLine)
		if line == "" || strings.HasPrefix(line, "#") || strings.HasPrefix(line, ";") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			section = strings.ToLower(strings.TrimSpace(line[1 : len(line)-1]))
			continue
		}
		key, value, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		key = strings.ToLower(strings.TrimSpace(key))
		value = strings.TrimSpace(value)
		switch section {
		case "interface":
			switch key {
			case "privatekey":
				profile.privateKey = value
			case "address":
				profile.addresses = append(profile.addresses, splitCSV(value)...)
			case "dns":
				profile.dnsServers = append(profile.dnsServers, splitCSV(value)...)
			case "mtu":
				if mtu, err := strconv.Atoi(value); err == nil && mtu > 0 {
					profile.mtu = mtu
				}
			}
		case "peer":
			switch key {
			case "publickey":
				profile.peerPublicKey = value
			case "allowedips":
				profile.allowedIPs = append(profile.allowedIPs, splitCSV(value)...)
			case "endpoint":
				profile.endpoint = value
			}
		}
	}
	if strings.TrimSpace(profile.privateKey) == "" {
		return nil, fmt.Errorf("Android WireGuard profile %s is missing Interface.PrivateKey", path)
	}
	if len(profile.addresses) == 0 {
		return nil, fmt.Errorf("Android WireGuard profile %s is missing Interface.Address", path)
	}
	if strings.TrimSpace(profile.peerPublicKey) == "" {
		return nil, fmt.Errorf("Android WireGuard profile %s is missing Peer.PublicKey", path)
	}
	if len(profile.allowedIPs) == 0 {
		return nil, fmt.Errorf("Android WireGuard profile %s is missing Peer.AllowedIPs", path)
	}
	return profile, nil
}

func splitCSV(value string) []string {
	parts := strings.Split(value, ",")
	out := make([]string, 0, len(parts))
	for _, part := range parts {
		if trimmed := strings.TrimSpace(part); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}
