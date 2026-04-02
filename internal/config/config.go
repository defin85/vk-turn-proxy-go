package config

import (
	"errors"
	"fmt"
	"strings"
	"time"
)

type TransportMode string

const (
	TransportModeAuto TransportMode = "auto"
	TransportModeTCP  TransportMode = "tcp"
	TransportModeUDP  TransportMode = "udp"
)

type ServerConfig struct {
	ListenAddr       string
	UpstreamAddr     string
	HandshakeTimeout time.Duration
	IdleTimeout      time.Duration
}

type ClientConfig struct {
	Provider      string
	Link          string
	ListenAddr    string
	PeerAddr      string
	Connections   int
	TURNServer    string
	TURNPort      string
	BindInterface string
	Mode          TransportMode
	UseDTLS       bool
}

type ProbeConfig struct {
	Provider      string
	Link          string
	BindInterface string
	OutputDir     string
	ListProviders bool
}

func DefaultServerConfig() ServerConfig {
	return ServerConfig{
		ListenAddr:       "0.0.0.0:56000",
		HandshakeTimeout: 30 * time.Second,
		IdleTimeout:      30 * time.Minute,
	}
}

func DefaultClientConfig() ClientConfig {
	return ClientConfig{
		ListenAddr:  "127.0.0.1:9000",
		Connections: 1,
		Mode:        TransportModeAuto,
		UseDTLS:     true,
	}
}

func DefaultProbeConfig() ProbeConfig {
	return ProbeConfig{
		OutputDir: "artifacts",
	}
}

func (c ServerConfig) Validate() error {
	if err := requireAddr("listen", c.ListenAddr); err != nil {
		return err
	}
	if err := requireAddr("upstream", c.UpstreamAddr); err != nil {
		return err
	}
	if c.HandshakeTimeout <= 0 {
		return errors.New("handshake timeout must be positive")
	}
	if c.IdleTimeout <= 0 {
		return errors.New("idle timeout must be positive")
	}

	return nil
}

func (c ClientConfig) Validate() error {
	if strings.TrimSpace(c.Provider) == "" {
		return errors.New("provider is required")
	}
	if strings.TrimSpace(c.Link) == "" {
		return errors.New("link is required")
	}
	if err := requireAddr("listen", c.ListenAddr); err != nil {
		return err
	}
	if err := requireAddr("peer", c.PeerAddr); err != nil {
		return err
	}
	if c.Connections <= 0 {
		return errors.New("connections must be positive")
	}
	if c.Mode != TransportModeAuto && c.Mode != TransportModeTCP && c.Mode != TransportModeUDP {
		return fmt.Errorf("unsupported transport mode %q", c.Mode)
	}

	return nil
}

func (c ProbeConfig) Validate() error {
	if c.ListProviders {
		return nil
	}
	if strings.TrimSpace(c.Provider) == "" {
		return errors.New("provider is required")
	}
	if strings.TrimSpace(c.Link) == "" {
		return errors.New("link is required")
	}
	if strings.TrimSpace(c.OutputDir) == "" {
		return errors.New("output dir is required")
	}

	return nil
}

func requireAddr(name string, value string) error {
	if strings.TrimSpace(value) == "" {
		return fmt.Errorf("%s address is required", name)
	}

	return nil
}
