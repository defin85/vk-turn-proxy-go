package session

import (
	"fmt"
	"net"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type transportPlan struct {
	Mode     config.TransportMode
	TURNMode transport.TURNMode
	PeerMode transport.PeerMode
	BindIP   net.IP
}

func buildTransportPlan(cfg config.ClientConfig) (transportPlan, error) {
	plan := transportPlan{
		Mode: cfg.Mode,
	}
	if plan.Mode == config.TransportModeAuto {
		plan.Mode = config.TransportModeUDP
	}

	if cfg.Connections != 1 {
		return transportPlan{}, fmt.Errorf("unsupported transport policy: connections=%d", cfg.Connections)
	}

	switch plan.Mode {
	case config.TransportModeUDP:
		plan.TURNMode = transport.TURNModeUDP
	case config.TransportModeTCP:
		plan.TURNMode = transport.TURNModeTCP
	default:
		return transportPlan{}, fmt.Errorf("unsupported transport mode %q", plan.Mode)
	}

	if cfg.UseDTLS {
		plan.PeerMode = transport.PeerModeDTLS
	} else {
		plan.PeerMode = transport.PeerModePlain
	}

	if trimmed := strings.TrimSpace(cfg.BindInterface); trimmed != "" {
		ip := net.ParseIP(trimmed)
		if ip == nil {
			return transportPlan{}, fmt.Errorf("unsupported bind-interface %q: expected literal IP address", cfg.BindInterface)
		}
		plan.BindIP = append(net.IP(nil), ip...)
	}

	return plan, nil
}
