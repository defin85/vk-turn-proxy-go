package main

import (
	"context"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	os.Exit(runClientd(ctx, os.Stdout, os.Stderr, os.Args[1:]))
}

func runClientd(ctx context.Context, stdout, stderr *os.File, args []string) int {
	listenAddr, logLevel, err := parseFlags(stderr, args)
	if err != nil {
		return 2
	}
	if err := validateLoopbackListen(listenAddr); err != nil {
		fmt.Fprintf(stderr, "invalid clientd listen address: %v\n", err)
		return 2
	}

	logger := observe.NewLoggerWriter(logLevel, stdout)
	host := clientcontrol.New(clientcontrol.WithLogger(logger))

	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		fmt.Fprintf(stderr, "clientd listen failed: %v\n", err)
		return 1
	}
	defer listener.Close()

	server := &http.Server{
		Handler: clientcontrol.Handler(host),
		BaseContext: func(net.Listener) context.Context {
			return ctx
		},
	}
	logger.Info("client control plane listening", "listen", listener.Addr().String())

	errCh := make(chan error, 1)
	go func() {
		errCh <- server.Serve(listener)
	}()

	select {
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
		if err := <-errCh; err != nil && err != http.ErrServerClosed {
			fmt.Fprintf(stderr, "clientd stopped: %v\n", err)
			return 1
		}
		return 0
	case err := <-errCh:
		if err != nil && err != http.ErrServerClosed {
			fmt.Fprintf(stderr, "clientd stopped: %v\n", err)
			return 1
		}
		return 0
	}
}

func parseFlags(stderr *os.File, args []string) (string, string, error) {
	listenAddr := "127.0.0.1:7777"
	logLevel := "info"
	flags := flag.NewFlagSet("clientd", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&listenAddr, "listen", listenAddr, "local control-plane listen address")
	flags.StringVar(&logLevel, "log-level", logLevel, "log level: debug|info|warn|error")
	return listenAddr, logLevel, flags.Parse(args)
}

func validateLoopbackListen(listenAddr string) error {
	host, _, err := net.SplitHostPort(strings.TrimSpace(listenAddr))
	if err != nil {
		return err
	}
	switch strings.TrimSpace(host) {
	case "127.0.0.1", "localhost", "::1":
		return nil
	default:
		return fmt.Errorf("listen host %q is not loopback", host)
	}
}
