package session

import (
	"fmt"
	"net"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/overlay"
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
	Ingress  overlay.AdapterKind
	Mode     config.TransportMode
	TURNMode transport.TURNMode
	PeerMode transport.PeerMode
	BindIP   net.IP
}

func ValidatePolicy(cfg config.ClientConfig) error {
	if err := cfg.Validate(); err != nil {
		return err
	}
	_, err := buildSessionPlan(cfg, Dependencies{})
	return err
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
		Ingress: overlay.NormalizeAdapter(overlay.AdapterKind(cfg.Ingress)),
		Mode:    cfg.Mode,
	}
	if err := overlay.ValidateAdapter(plan.Ingress, "client ingress"); err != nil {
		return transportPlan{}, err
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
	if plan.Ingress == overlay.AdapterTCP && plan.PeerMode != transport.PeerModeDTLS {
		return transportPlan{}, fmt.Errorf("unsupported ingress adapter %q with dtls=%t: the first tcp overlay slice requires a dtls-backed peer server", plan.Ingress, cfg.UseDTLS)
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
