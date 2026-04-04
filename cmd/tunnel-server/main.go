package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"log/slog"
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

	os.Exit(runServer(ctx, os.Stdout, os.Stderr, os.Args[1:]))
}

func runServer(ctx context.Context, stdout io.Writer, stderr io.Writer, args []string) int {
	cfg, logLevel, metricsListen, err := parseServerFlags(stderr, args)
	if err != nil {
		return 2
	}

	logger := observe.NewLoggerWriter(logLevel, stdout)
	metrics := observe.NewMetrics()
	observer := observe.NewObserver(observe.RuntimeServer, logger, metrics, observe.Metadata{
		SessionID: observe.NewSessionID(),
		Provider:  "none",
		PeerMode:  "dtls",
	})
	if err := cfg.Validate(); err != nil {
		observer.RecordSessionFailure("policy_validate", true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", "policy_validate",
			"result", "failed",
			"error", err,
		)
		fmt.Fprintf(stderr, "init server: %v\n", err)
		return 2
	}
	if _, err := observe.StartMetricsServer(ctx, metricsListen, metrics, logger); err != nil {
		observer.RecordSessionFailure("metrics_listen", true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", "metrics_listen",
			"result", "failed",
			"error", err,
		)
		fmt.Fprintf(stderr, "server metrics failed: %v\n", err)
		return 1
	}

	server, err := tunnelserver.New(cfg, logger)
	if err != nil {
		observer.RecordSessionFailure("server_init", true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", "server_init",
			"result", "failed",
			"error", err,
		)
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
