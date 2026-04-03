package session

import (
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

const (
	defaultWorkerRestartBackoff = 200 * time.Millisecond
	defaultMaxWorkerRestarts    = 1
)

type sessionPlan struct {
	Connections       int
	RestartBackoff    time.Duration
	MaxWorkerRestarts int
	Transport         transportPlan
}

type transportPlan struct {
	Mode     config.TransportMode
	TURNMode transport.TURNMode
	PeerMode transport.PeerMode
	BindIP   net.IP
}

func buildSessionPlan(cfg config.ClientConfig, deps Dependencies) (sessionPlan, error) {
	transportPlan, err := buildTransportPlan(cfg)
	if err != nil {
		return sessionPlan{}, err
	}

	plan := sessionPlan{
		Connections:       cfg.Connections,
		RestartBackoff:    defaultWorkerRestartBackoff,
		MaxWorkerRestarts: defaultMaxWorkerRestarts,
		Transport:         transportPlan,
	}
	if deps.RestartBackoff > 0 {
		plan.RestartBackoff = deps.RestartBackoff
	}
	if deps.MaxWorkerRestarts > 0 {
		plan.MaxWorkerRestarts = deps.MaxWorkerRestarts
	}

	return plan, nil
}

func buildTransportPlan(cfg config.ClientConfig) (transportPlan, error) {
	plan := transportPlan{
		Mode: cfg.Mode,
	}
	if plan.Mode == config.TransportModeAuto {
		plan.Mode = config.TransportModeUDP
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
