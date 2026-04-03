package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/session"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	os.Exit(runClient(ctx, os.Stderr, os.Args[1:], newRegistry()))
}

func runClient(ctx context.Context, stderr io.Writer, args []string, registry *provider.Registry) int {
	cfg, logLevel, metricsListen, err := parseClientFlags(stderr, args)
	if err != nil {
		return 2
	}
	if err := cfg.Validate(); err != nil {
		fmt.Fprintf(stderr, "invalid client config: %v\n", err)
		return 2
	}

	logger := observe.NewLogger(logLevel)
	metrics := observe.NewMetrics()
	if _, err := observe.StartMetricsServer(ctx, metricsListen, metrics, logger); err != nil {
		fmt.Fprintf(stderr, "client metrics failed: %v\n", err)
		return 1
	}
	err = session.Run(ctx, cfg, session.Dependencies{
		Registry:  registry,
		Logger:    logger,
		Metrics:   metrics,
		SessionID: session.NewID(),
	})
	if err != nil {
		if stage, ok := runstage.FromError(err); ok {
			fmt.Fprintf(stderr, "client runtime failed stage=%s: %v\n", stage, err)
		} else {
			fmt.Fprintf(stderr, "client runtime failed: %v\n", err)
		}

		return exitCode(err)
	}

	return 0
}

func parseClientFlags(stderr io.Writer, args []string) (config.ClientConfig, string, string, error) {
	cfg := config.DefaultClientConfig()
	logLevel := "info"
	metricsListen := ""
	flags := flag.NewFlagSet("tunnel-client", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&logLevel, "log-level", logLevel, "log level: debug|info|warn|error")
	flags.StringVar(&metricsListen, "metrics-listen", metricsListen, "optional metrics listen address")
	flags.StringVar(&cfg.Provider, "provider", cfg.Provider, "provider name")
	flags.StringVar(&cfg.Link, "link", cfg.Link, "provider link or invite")
	flags.StringVar(&cfg.ListenAddr, "listen", cfg.ListenAddr, "local UDP listen address")
	flags.StringVar(&cfg.PeerAddr, "peer", cfg.PeerAddr, "remote server address")
	flags.IntVar(&cfg.Connections, "connections", cfg.Connections, "number of parallel transport connections")
	flags.StringVar(&cfg.TURNServer, "turn", cfg.TURNServer, "override TURN server IP or host")
	flags.StringVar(&cfg.TURNPort, "port", cfg.TURNPort, "override TURN server port")
	flags.StringVar(&cfg.BindInterface, "bind-interface", cfg.BindInterface, "literal local IP for outbound TURN setup")
	flags.BoolVar(&cfg.UseDTLS, "dtls", cfg.UseDTLS, "wrap transport in DTLS")
	flags.Func("mode", "transport mode: auto|tcp|udp", func(value string) error {
		cfg.Mode = config.TransportMode(value)
		return nil
	})

	return cfg, logLevel, metricsListen, flags.Parse(args)
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
