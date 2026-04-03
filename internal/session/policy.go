package session

import (
	"fmt"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
)

func normalizePolicy(cfg config.ClientConfig) config.ClientConfig {
	if cfg.Mode == config.TransportModeAuto {
		cfg.Mode = config.TransportModeUDP
	}

	return cfg
}

func validatePolicy(cfg config.ClientConfig) error {
	if cfg.Connections != 1 {
		return fmt.Errorf("unsupported first-slice policy: connections=%d", cfg.Connections)
	}
	if !cfg.UseDTLS {
		return fmt.Errorf("unsupported first-slice policy: dtls=false")
	}
	if cfg.Mode == config.TransportModeTCP {
		return fmt.Errorf("unsupported first-slice policy: mode=%s", cfg.Mode)
	}
	if strings.TrimSpace(cfg.BindInterface) != "" {
		return fmt.Errorf("unsupported first-slice policy: bind-interface=%q", cfg.BindInterface)
	}

	return nil
}

func applyTURNOverrides(creds string, hostOverride string, portOverride string) (string, error) {
	host, port, err := netSplitHostPort(creds)
	if err != nil {
		return "", err
	}
	if trimmed := strings.TrimSpace(hostOverride); trimmed != "" {
		host = trimmed
	}
	if trimmed := strings.TrimSpace(portOverride); trimmed != "" {
		port = trimmed
	}

	return netJoinHostPort(host, port)
}
