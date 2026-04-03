package session

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type fakeAdapter struct {
	name       string
	resolution provider.Resolution
	err        error
	calls      int
}

func (f *fakeAdapter) Name() string { return f.name }

func (f *fakeAdapter) Resolve(context.Context, string) (provider.Resolution, error) {
	f.calls++
	return f.resolution, f.err
}

type fakeRunner struct {
	run func(context.Context) error
}

func (f fakeRunner) Run(ctx context.Context) error {
	if f.run == nil {
		return nil
	}

	return f.run(ctx)
}

func TestRunRejectsUnsupportedPolicyBeforeProviderResolution(t *testing.T) {
	cfg := validClientConfig()
	cfg.BindInterface = "eth0"

	adapter := &fakeAdapter{name: "fake"}
	runnerCalled := false

	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(transport.ClientConfig) transport.Runner {
			runnerCalled = true
			return fakeRunner{}
		},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.PolicyValidate {
		t.Fatalf("unexpected stage: %v", err)
	}
	if adapter.calls != 0 {
		t.Fatalf("provider Resolve() calls = %d, want 0", adapter.calls)
	}
	if runnerCalled {
		t.Fatal("runner should not be created for unsupported policy")
	}
}

func TestRunWrapsProviderResolutionFailure(t *testing.T) {
	cfg := validClientConfig()
	adapter := &fakeAdapter{
		name: "fake",
		err:  errors.New("provider boom"),
	}
	runnerCalled := false

	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(transport.ClientConfig) transport.Runner {
			runnerCalled = true
			return fakeRunner{}
		},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.ProviderResolve {
		t.Fatalf("unexpected stage: %v", err)
	}
	if adapter.calls != 1 {
		t.Fatalf("provider Resolve() calls = %d, want 1", adapter.calls)
	}
	if runnerCalled {
		t.Fatal("runner should not be created for provider failure")
	}
}

func TestRunAppliesTURNOverrides(t *testing.T) {
	cfg := validClientConfig()
	cfg.TURNServer = "override.example.test"
	cfg.TURNPort = "5349"

	adapter := &fakeAdapter{
		name: "fake",
		resolution: provider.Resolution{
			Credentials: provider.Credentials{
				Username: "user",
				Password: "pass",
				Address:  "turn.example.test:3478",
			},
		},
	}

	var got transport.ClientConfig
	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
			got = cfg
			return fakeRunner{}
		},
	})
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got.TURN.Address != "override.example.test:5349" {
		t.Fatalf("unexpected turn address %q", got.TURN.Address)
	}
	if got.TURN.Username != "user" || got.TURN.Password != "pass" {
		t.Fatalf("unexpected turn credentials %#v", got.TURN)
	}
}

func validClientConfig() config.ClientConfig {
	return config.ClientConfig{
		Provider:    "fake",
		Link:        "fake://link",
		ListenAddr:  "127.0.0.1:9000",
		PeerAddr:    "127.0.0.1:56000",
		Connections: 1,
		Mode:        config.TransportModeAuto,
		UseDTLS:     true,
	}
}

func testLogger() *slog.Logger {
	return slog.New(slog.NewTextHandler(io.Discard, nil))
}
