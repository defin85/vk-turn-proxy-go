package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

type clientHost interface {
	StartSession(context.Context, clientcontrol.StartSessionRequest) (clientcontrol.Session, error)
	WaitSession(context.Context, string) (clientcontrol.Session, error)
	StopSession(string) (clientcontrol.Session, error)
	MetricsHandler(string) (http.Handler, error)
}

var newClientHost = func(logger *slog.Logger, stdin io.Reader, stderr io.Writer, interactiveProvider bool, sessionID string) clientHost {
	options := []clientcontrol.Option{
		clientcontrol.WithLogger(logger),
		clientcontrol.WithSessionIDSource(func() string { return sessionID }),
	}
	if interactiveProvider {
		options = append(options, clientcontrol.WithCLIInteractivePrompts(stdin, stderr))
	}
	return clientcontrol.New(options...)
}

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	os.Exit(runClient(ctx, os.Stdin, os.Stdout, os.Stderr, os.Args[1:], newRegistry()))
}

func runClient(ctx context.Context, stdin io.Reader, stdout io.Writer, stderr io.Writer, args []string, _ *provider.Registry) int {
	cfg, logLevel, metricsListen, interactiveProvider, err := parseClientFlags(stderr, args)
	if err != nil {
		return 2
	}
	logger := observe.NewLoggerWriter(logLevel, stdout)
	sessionID := observe.NewSessionID()
	metrics := observe.NewMetrics()
	observer := observe.NewObserver(observe.RuntimeClient, logger, metrics, observe.Metadata{
		SessionID: sessionID,
		Provider:  cfg.Provider,
	})
	if err := cfg.Validate(); err != nil {
		observer.RecordSessionFailure(string(runstage.PolicyValidate), true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.PolicyValidate,
			"result", "failed",
			"error", err,
		)
		fmt.Fprintf(stderr, "invalid client config: %v\n", err)
		return 2
	}

	host := newClientHost(logger, stdin, stderr, interactiveProvider, sessionID)
	sessionState, err := host.StartSession(ctx, clientcontrol.StartSessionRequest{
		Spec: &clientcontrol.ProfileSpec{
			Provider:            cfg.Provider,
			Link:                cfg.Link,
			ListenAddr:          cfg.ListenAddr,
			PeerAddr:            cfg.PeerAddr,
			Connections:         cfg.Connections,
			TURNServer:          cfg.TURNServer,
			TURNPort:            cfg.TURNPort,
			BindInterface:       cfg.BindInterface,
			Mode:                clientcontrol.TransportMode(cfg.Mode),
			UseDTLS:             boolRef(cfg.UseDTLS),
			InteractiveProvider: interactiveProvider,
			LogLevel:            logLevel,
		},
	})
	if err != nil {
		observer.RecordSessionFailure(string(runstage.PolicyValidate), true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.PolicyValidate,
			"result", "failed",
			"error", err,
		)
		fmt.Fprintf(stderr, "invalid client config: %v\n", err)
		return 2
	}

	if metricsListen != "" {
		handler, err := host.MetricsHandler(sessionState.ID)
		if err != nil {
			observer.RecordSessionFailure("metrics_attach", true)
			observer.Emit(ctx, slog.LevelError, "runtime_failure",
				"stage", "metrics_attach",
				"result", "failed",
				"error", err,
			)
			fmt.Fprintf(stderr, "client metrics failed: %v\n", err)
			_, _ = host.StopSession(sessionState.ID)
			return 1
		}
		if _, err := startMetricsServer(ctx, metricsListen, handler, logger); err != nil {
			observer.RecordSessionFailure("metrics_listen", true)
			observer.Emit(ctx, slog.LevelError, "runtime_failure",
				"stage", "metrics_listen",
				"result", "failed",
				"error", err,
			)
			fmt.Fprintf(stderr, "client metrics failed: %v\n", err)
			_, _ = host.StopSession(sessionState.ID)
			return 1
		}
	}

	sessionState, err = host.WaitSession(ctx, sessionState.ID)
	if err != nil && !errors.Is(err, context.Canceled) {
		fmt.Fprintf(stderr, "client runtime failed: %v\n", err)
		return 1
	}
	if sessionState.Failure != nil {
		if stage := sessionState.Failure.Stage; stage != "" {
			fmt.Fprintf(stderr, "client runtime failed stage=%s: %s\n", stage, sessionState.Failure.Message)
		} else {
			fmt.Fprintf(stderr, "client runtime failed: %s\n", sessionState.Failure.Message)
		}
		if sessionState.Failure.NotImplemented || strings.Contains(sessionState.Failure.Message, provider.ErrNotImplemented.Error()) {
			return 3
		}
		return 1
	}
	return 0
}

func parseClientFlags(stderr io.Writer, args []string) (config.ClientConfig, string, string, bool, error) {
	cfg := config.DefaultClientConfig()
	logLevel := "info"
	metricsListen := ""
	interactiveProvider := false
	flags := flag.NewFlagSet("tunnel-client", flag.ContinueOnError)
	flags.SetOutput(stderr)
	flags.StringVar(&logLevel, "log-level", logLevel, "log level: debug|info|warn|error")
	flags.StringVar(&metricsListen, "metrics-listen", metricsListen, "optional metrics listen address")
	flags.BoolVar(&interactiveProvider, "interactive-provider", interactiveProvider, "allow operator-assisted provider challenges, including browser-observed VK captcha continuation and live preview/post-preview contour capture")
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

	return cfg, logLevel, metricsListen, interactiveProvider, flags.Parse(args)
}

func boolRef(value bool) *bool {
	out := value
	return &out
}

func newRegistry() *provider.Registry {
	return provider.NewRegistry(genericturn.New(), vk.New())
}

func startMetricsServer(ctx context.Context, listenAddr string, handler http.Handler, logger *slog.Logger) (net.Addr, error) {
	if strings.TrimSpace(listenAddr) == "" {
		return nil, nil
	}
	listener, err := net.Listen("tcp", listenAddr)
	if err != nil {
		return nil, err
	}
	server := &http.Server{Handler: handler}
	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		_ = server.Shutdown(shutdownCtx)
	}()
	go func() {
		if err := server.Serve(listener); err != nil && !errors.Is(err, http.ErrServerClosed) && logger != nil {
			logger.Error("client metrics server stopped", "error", err)
		}
	}()
	return listener.Addr(), nil
}
