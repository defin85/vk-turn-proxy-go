package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
	"github.com/defin85/vk-turn-proxy-go/internal/session"
)

func main() {
	cfg := config.DefaultClientConfig()
	logLevel := flag.String("log-level", "info", "log level: debug|info|warn|error")
	flag.StringVar(&cfg.Provider, "provider", cfg.Provider, "provider name")
	flag.StringVar(&cfg.Link, "link", cfg.Link, "provider link or invite")
	flag.StringVar(&cfg.ListenAddr, "listen", cfg.ListenAddr, "local UDP listen address")
	flag.StringVar(&cfg.PeerAddr, "peer", cfg.PeerAddr, "remote server address")
	flag.IntVar(&cfg.Connections, "connections", cfg.Connections, "number of parallel transport connections")
	flag.StringVar(&cfg.TURNServer, "turn", cfg.TURNServer, "override TURN server IP or host")
	flag.StringVar(&cfg.TURNPort, "port", cfg.TURNPort, "override TURN server port")
	flag.StringVar(&cfg.BindInterface, "bind-interface", cfg.BindInterface, "preferred local interface or address")
	flag.BoolVar(&cfg.UseDTLS, "dtls", cfg.UseDTLS, "wrap transport in DTLS")
	flag.Func("mode", "transport mode: auto|tcp|udp", func(value string) error {
		cfg.Mode = config.TransportMode(value)
		return nil
	})
	flag.Parse()

	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(os.Stderr, "invalid client config: %v\n", err)
		os.Exit(2)
	}

	logger := observe.NewLogger(*logLevel)
	sessionID := session.NewID()
	registry := newRegistry()
	adapter, err := registry.Get(cfg.Provider)
	if err != nil {
		fmt.Fprintf(os.Stderr, "provider lookup: %v\n", err)
		os.Exit(2)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	logger.Info("client scaffold initialized",
		"session_id", sessionID,
		"provider", cfg.Provider,
		"listen", cfg.ListenAddr,
		"peer", cfg.PeerAddr,
		"mode", cfg.Mode,
		"dtls", cfg.UseDTLS,
	)

	if _, err := adapter.Resolve(ctx, cfg.Link); err != nil {
		fmt.Fprintf(os.Stderr, "resolve provider credentials: %v\n", err)
		os.Exit(exitCode(err))
	}

	fmt.Fprintln(os.Stderr, "client transport core is not ported yet")
	os.Exit(3)
}

func exitCode(err error) int {
	if errors.Is(err, provider.ErrNotImplemented) {
		return 3
	}

	return 1
}

func newRegistry() *provider.Registry {
	return provider.NewRegistry(genericturn.New(), vk.New())
}
