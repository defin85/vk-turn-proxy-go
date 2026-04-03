package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"os"
	"os/signal"
	"syscall"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/tunnelserver"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	os.Exit(runServer(ctx, os.Stderr, os.Args[1:]))
}

func runServer(ctx context.Context, stderr io.Writer, args []string) int {
	cfg, logLevel, metricsListen, err := parseServerFlags(stderr, args)
	if err != nil {
		return 2
	}

	logger := observe.NewLogger(logLevel)
	metrics := observe.NewMetrics()
	if _, err := observe.StartMetricsServer(ctx, metricsListen, metrics, logger); err != nil {
		fmt.Fprintf(stderr, "server metrics failed: %v\n", err)
		return 1
	}

	server, err := tunnelserver.New(cfg, logger)
	if err != nil {
		fmt.Fprintf(stderr, "init server: %v\n", err)
		return 2
	}
	server.SetMetrics(metrics)

	if err := server.Run(ctx); err != nil {
		fmt.Fprintf(stderr, "run server: %v\n", err)
		return 1
	}

	return 0
}

func parseServerFlags(stderr io.Writer, args []string) (config.ServerConfig, string, string, error) {
	cfg := config.DefaultServerConfig()
	logLevel := "info"
	metricsListen := ""
	flags := flag.NewFlagSet("tunnel-server", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&logLevel, "log-level", logLevel, "log level: debug|info|warn|error")
	flags.StringVar(&metricsListen, "metrics-listen", metricsListen, "optional metrics listen address")
	flags.StringVar(&cfg.ListenAddr, "listen", cfg.ListenAddr, "listen on ip:port")
	flags.StringVar(&cfg.UpstreamAddr, "connect", cfg.UpstreamAddr, "upstream UDP address host:port")
	flags.DurationVar(&cfg.HandshakeTimeout, "handshake-timeout", cfg.HandshakeTimeout, "DTLS handshake timeout")
	flags.DurationVar(&cfg.IdleTimeout, "idle-timeout", cfg.IdleTimeout, "idle read/write timeout")

	return cfg, logLevel, metricsListen, flags.Parse(args)
}
