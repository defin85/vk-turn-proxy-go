package session

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type RunnerFactory func(transport.ClientConfig) transport.Runner

type Dependencies struct {
	Registry          *provider.Registry
	Logger            *slog.Logger
	Metrics           *observe.Metrics
	NewRunner         RunnerFactory
	SessionID         ID
	RestartBackoff    time.Duration
	MaxWorkerRestarts int
}

func Run(ctx context.Context, cfg config.ClientConfig, deps Dependencies) error {
	if ctx == nil {
		ctx = context.Background()
	}
	if deps.Registry == nil {
		return runstage.Wrap(runstage.ProviderResolve, fmt.Errorf("provider registry is required"))
	}
	logger := deps.Logger
	if logger == nil {
		logger = slog.Default()
	}
	sessionID := deps.SessionID
	if sessionID == "" {
		sessionID = NewID()
	}
	deps.SessionID = sessionID
	baseLogger := logger
	bootstrapObserver := observe.NewObserver(observe.RuntimeClient, baseLogger, deps.Metrics, clientObserverMetadata(cfg, sessionID, nil))
	if deps.NewRunner == nil {
		deps.NewRunner = transport.NewClientRunner
	}
	if err := cfg.Validate(); err != nil {
		bootstrapObserver.RecordSessionFailure(string(runstage.PolicyValidate), true)
		bootstrapObserver.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.PolicyValidate,
			"result", "failed",
			"error", err,
		)
		return runstage.Wrap(runstage.PolicyValidate, err)
	}

	plan, err := buildSessionPlan(cfg, deps)
	if err != nil {
		bootstrapObserver.RecordSessionFailure(string(runstage.PolicyValidate), true)
		bootstrapObserver.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.PolicyValidate,
			"result", "failed",
			"error", err,
		)
		return runstage.Wrap(runstage.PolicyValidate, err)
	}
	cfg.Mode = plan.Transport.Mode
	observer := observe.NewObserver(observe.RuntimeClient, baseLogger, deps.Metrics, clientObserverMetadata(cfg, sessionID, &plan))
	logger = observer.Logger()

	adapter, err := deps.Registry.Get(cfg.Provider)
	if err != nil {
		observer.RecordSessionFailure(string(runstage.ProviderResolve), true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.ProviderResolve,
			"result", "failed",
			"error", err,
		)
		return runstage.Wrap(runstage.ProviderResolve, err)
	}

	observer.Emit(ctx, slog.LevelInfo, "runtime_startup",
		"stage", "bootstrap",
		"result", "started",
		"provider", cfg.Provider,
		"listen", cfg.ListenAddr,
		"peer", cfg.PeerAddr,
		"mode", cfg.Mode,
		"dtls", cfg.UseDTLS,
		"connections", cfg.Connections,
	)

	resolution, err := adapter.Resolve(ctx, cfg.Link)
	if err != nil {
		observer.RecordSessionFailure(string(runstage.ProviderResolve), true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.ProviderResolve,
			"result", "failed",
			"error", err,
		)
		return runstage.Wrap(runstage.ProviderResolve, err)
	}

	turnAddr, err := applyTURNOverrides(resolution.Credentials.Address, cfg.TURNServer, cfg.TURNPort)
	if err != nil {
		observer.RecordSessionFailure(string(runstage.ProviderResolve), true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.ProviderResolve,
			"result", "failed",
			"error", err,
		)
		return runstage.Wrap(runstage.ProviderResolve, err)
	}

	observer.Emit(ctx, slog.LevelInfo, "provider_resolution",
		"stage", runstage.ProviderResolve,
		"result", "succeeded",
		"resolution_method", resolution.Metadata["resolution_method"],
		"turn_addr", turnAddr,
		"peer", cfg.PeerAddr,
		"listen", cfg.ListenAddr,
	)

	localConn, err := net.ListenPacket("udp", cfg.ListenAddr)
	if err != nil {
		observer.RecordTransportFailure(string(runstage.LocalBind))
		observer.RecordSessionFailure(string(runstage.LocalBind), true)
		observer.Emit(ctx, slog.LevelError, "runtime_failure",
			"stage", runstage.LocalBind,
			"result", "failed",
			"error", err,
		)
		return runstage.Wrap(runstage.LocalBind, fmt.Errorf("bind local listener: %w", err))
	}
	defer transportClosePacketConn(localConn)

	if err := runSupervisedSession(ctx, localConn, transport.ClientConfig{
		ListenAddr: cfg.ListenAddr,
		PeerAddr:   cfg.PeerAddr,
		TURN: transport.TURNCredentials{
			Address:  turnAddr,
			Username: resolution.Credentials.Username,
			Password: resolution.Credentials.Password,
		},
		TURNMode: plan.Transport.TURNMode,
		PeerMode: plan.Transport.PeerMode,
		BindIP:   append(net.IP(nil), plan.Transport.BindIP...),
		Logger:   logger,
		Hooks: transport.ClientHooks{
			OnTraffic: observer.RecordForward,
		},
	}, deps, plan, observer); err != nil {
		return err
	}

	observer.SetActiveWorkers(0)
	observer.Emit(ctx, slog.LevelInfo, "runtime_stop",
		"stage", "shutdown",
		"result", "stopped",
	)

	return nil
}

func transportClosePacketConn(conn net.PacketConn) {
	if conn == nil {
		return
	}

	_ = conn.Close()
}

func clientObserverMetadata(cfg config.ClientConfig, sessionID ID, plan *sessionPlan) observe.Metadata {
	meta := observe.Metadata{
		SessionID: string(sessionID),
		Provider:  cfg.Provider,
	}
	if plan != nil {
		meta.TURNMode = string(plan.Transport.TURNMode)
		meta.PeerMode = string(plan.Transport.PeerMode)
		return meta
	}

	switch cfg.Mode {
	case config.TransportModeAuto, config.TransportModeTCP, config.TransportModeUDP:
		meta.TURNMode = string(cfg.Mode)
	}
	if cfg.UseDTLS {
		meta.PeerMode = string(transport.PeerModeDTLS)
	} else {
		meta.PeerMode = string(transport.PeerModePlain)
	}

	return meta
}
