package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/tunnelserver"
)

func main() {
	cfg := config.DefaultServerConfig()
	logLevel := flag.String("log-level", "info", "log level: debug|info|warn|error")
	flag.StringVar(&cfg.ListenAddr, "listen", cfg.ListenAddr, "listen on ip:port")
	flag.StringVar(&cfg.UpstreamAddr, "connect", cfg.UpstreamAddr, "upstream UDP address host:port")
	flag.DurationVar(&cfg.HandshakeTimeout, "handshake-timeout", cfg.HandshakeTimeout, "DTLS handshake timeout")
	flag.DurationVar(&cfg.IdleTimeout, "idle-timeout", cfg.IdleTimeout, "idle read/write timeout")
	flag.Parse()

	logger := observe.NewLogger(*logLevel)
	server, err := tunnelserver.New(cfg, logger)
	if err != nil {
		fmt.Fprintf(os.Stderr, "init server: %v\n", err)
		os.Exit(2)
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	if err := server.Run(ctx); err != nil {
		fmt.Fprintf(os.Stderr, "run server: %v\n", err)
		os.Exit(1)
	}
}
