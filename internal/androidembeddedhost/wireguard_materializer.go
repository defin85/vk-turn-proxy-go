package androidembeddedhost

import (
	"context"
	"fmt"
	"strings"
	"sync"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/wireguardprofile"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

var (
	androidWireGuardProfilePathMu sync.RWMutex
	androidWireGuardProfilePath   string
)

func defaultAndroidWireGuardTurnMaterializer() clientcontrol.WireGuardTurnMaterializer {
	return func(
		_ context.Context,
		req clientcontrol.WireGuardTurnMaterializeRequest,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		profilePath, ok := detectAndroidWireGuardProfilePath()
		if !ok {
			return nil, fmt.Errorf("explicit Android WireGuard profile is not configured")
		}
		profile, err := wireguardprofile.Load(profilePath)
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
			peerEndpointAddress = strings.TrimSpace(profile.Endpoint)
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
			ClientPrivateKey:     profile.PrivateKey,
			ClientAddresses:      append([]string(nil), profile.Addresses...),
			PeerPublicKey:        profile.PeerPublicKey,
			AllowedIPs:           append([]string(nil), profile.AllowedIPs...),
			DNSServers:           append([]string(nil), profile.DNSServers...),
			MTU:                  profile.MTU,
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
		if wireguardprofile.FileExists(override) {
			return override, true
		}
		return "", false
	}
	return "", false
}
