package session

import (
	"context"
	"fmt"
	"log/slog"
	"net"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type RunnerFactory func(transport.ClientConfig) transport.Runner

type Dependencies struct {
	Registry  *provider.Registry
	Logger    *slog.Logger
	NewRunner RunnerFactory
	SessionID ID
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
	if deps.SessionID != "" {
		logger = logger.With("session_id", deps.SessionID)
	}
	if deps.NewRunner == nil {
		deps.NewRunner = transport.NewClientRunner
	}
	if err := cfg.Validate(); err != nil {
		return runstage.Wrap(runstage.PolicyValidate, err)
	}

	plan, err := buildTransportPlan(cfg)
	if err != nil {
		return runstage.Wrap(runstage.PolicyValidate, err)
	}
	cfg.Mode = plan.Mode

	adapter, err := deps.Registry.Get(cfg.Provider)
	if err != nil {
		return runstage.Wrap(runstage.ProviderResolve, err)
	}

	logger.Info("client session bootstrap started",
		"provider", cfg.Provider,
		"listen", cfg.ListenAddr,
		"peer", cfg.PeerAddr,
		"mode", cfg.Mode,
		"dtls", cfg.UseDTLS,
	)

	resolution, err := adapter.Resolve(ctx, cfg.Link)
	if err != nil {
		return runstage.Wrap(runstage.ProviderResolve, err)
	}

	turnAddr, err := applyTURNOverrides(resolution.Credentials.Address, cfg.TURNServer, cfg.TURNPort)
	if err != nil {
		return runstage.Wrap(runstage.ProviderResolve, err)
	}

	runner := deps.NewRunner(transport.ClientConfig{
		ListenAddr: cfg.ListenAddr,
		PeerAddr:   cfg.PeerAddr,
		TURN: transport.TURNCredentials{
			Address:  turnAddr,
			Username: resolution.Credentials.Username,
			Password: resolution.Credentials.Password,
		},
		TURNMode: plan.TURNMode,
		PeerMode: plan.PeerMode,
		BindIP:   append(net.IP(nil), plan.BindIP...),
		Logger:   logger,
	})

	logger.Info("client session resolved provider credentials",
		"turn_addr", turnAddr,
		"peer", cfg.PeerAddr,
		"listen", cfg.ListenAddr,
	)

	if err := runner.Run(ctx); err != nil {
		if stage, ok := runstage.FromError(err); ok {
			logger.Error("client session failed", "stage", stage, "err", err)
		} else {
			logger.Error("client session failed", "err", err)
		}

		return err
	}

	logger.Info("client session stopped")

	return nil
}
