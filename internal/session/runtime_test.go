package session

import (
	"context"
	"errors"
	"io"
	"log/slog"
	"sort"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/config"
	"github.com/defin85/vk-turn-proxy-go/internal/observe"
	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/runstage"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type fakeAdapter struct {
	name       string
	resolution provider.Resolution
	err        error
	calls      int
	resolve    func(context.Context, string) (provider.Resolution, error)
}

func (f *fakeAdapter) Name() string { return f.name }

func (f *fakeAdapter) Resolve(ctx context.Context, link string) (provider.Resolution, error) {
	f.calls++
	if f.resolve != nil {
		return f.resolve(ctx, link)
	}
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
	handler := newCaptureHandler()
	metrics := observe.NewMetrics()

	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   slog.New(handler),
		Metrics:  metrics,
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
	record := findRecord(t, handler.records(), "runtime_failure")
	if got := record.attrs["stage"]; got != runstage.PolicyValidate {
		t.Fatalf("runtime_failure stage = %#v", got)
	}
	text := metrics.Prometheus()
	for _, expected := range []string{
		"vk_turn_proxy_runtime_session_failures_total",
		"vk_turn_proxy_runtime_startup_stage_failures_total",
		`runtime="client"`,
		`provider="fake"`,
		`turn_mode="auto"`,
		`peer_mode="dtls"`,
		`stage="policy_validate"`,
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("metrics output missing %q:\n%s", expected, text)
		}
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

func TestRunPassesBrowserContinuationHandlerBeforeLocalBind(t *testing.T) {
	cfg := validClientConfig()
	cfg.ListenAddr = reserveUDPAddr(t)

	adapter := &fakeAdapter{
		name: "fake",
		resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
			handler := provider.BrowserContinuationHandlerFromContext(ctx)
			if handler == nil {
				t.Fatal("browser continuation handler is required")
			}
			if _, err := handler.Continue(ctx, fakeRuntimeChallenge{
				provider: "vk",
				stage:    "vk_calls_get_anonymous_token",
				kind:     "captcha",
				prompt:   "complete captcha",
				openURL:  "https://example.test/challenge",
			}); err != nil {
				return provider.Resolution{}, err
			}
			return provider.Resolution{}, errors.New("provider interaction completed")
		},
	}
	runnerCalled := false
	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		return &provider.BrowserContinuation{}, nil
	}))

	err := Run(ctx, cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
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
	if runnerCalled {
		t.Fatal("runner should not be created before browser-observed provider resolution succeeds")
	}
	mustRebindPacket(t, cfg.ListenAddr)
}

func TestRunFailsClosedOnPreviewOnlyProviderResolutionBeforeLocalBind(t *testing.T) {
	cfg := validClientConfig()
	cfg.Provider = "vk"
	cfg.ListenAddr = reserveUDPAddr(t)

	adapter := &fakeAdapter{
		name: "vk",
		err: &provider.ArtifactError{
			Err: errors.New("vk stage vk_calls_get_call_preview [browser_preview_only]"),
			ProbeArtifact: &provider.ProbeArtifact{
				Provider: "vk",
				Stages: []provider.ProbeArtifactStage{
					{Name: "vk_login_anonym_token", EndpointID: "vk_login_anonym_token"},
					{Name: "vk_calls_get_anonymous_token", EndpointID: "vk_calls_get_anonymous_token"},
					{Name: "vk_browser_login_anonym_token_messages", EndpointID: "vk_browser_login_anonym_token_messages"},
					{Name: "vk_calls_get_call_preview", EndpointID: "vk_calls_get_call_preview"},
				},
				Outcome: provider.ProbeArtifactOutcome{
					ResultKind: "provider_error",
					ProviderError: &provider.ProbeArtifactProviderError{
						Stage: "vk_calls_get_call_preview",
						Code:  "browser_preview_only",
					},
				},
			},
		},
	}
	runnerCalled := false

	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
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
		t.Fatal("runner should not be created for preview-only provider resolution")
	}
	mustRebindPacket(t, cfg.ListenAddr)
}

func TestRunFailsClosedOnPostPreviewUnsupportedProviderResolutionBeforeLocalBind(t *testing.T) {
	cfg := validClientConfig()
	cfg.Provider = "vk"
	cfg.ListenAddr = reserveUDPAddr(t)

	adapter := &fakeAdapter{
		name: "vk",
		err: &provider.ArtifactError{
			Err: errors.New("vk stage ok_anonym_login [browser_post_preview_unsupported]"),
			ProbeArtifact: &provider.ProbeArtifact{
				Provider: "vk",
				Stages: []provider.ProbeArtifactStage{
					{Name: "vk_login_anonym_token", EndpointID: "vk_login_anonym_token"},
					{Name: "vk_calls_get_anonymous_token", EndpointID: "vk_calls_get_anonymous_token"},
					{Name: "vk_browser_login_anonym_token_messages", EndpointID: "vk_browser_login_anonym_token_messages"},
					{Name: "vk_calls_get_call_preview", EndpointID: "vk_calls_get_call_preview"},
					{Name: "ok_anonym_login", EndpointID: "ok_anonym_login"},
				},
				Outcome: provider.ProbeArtifactOutcome{
					ResultKind: "provider_error",
					ProviderError: &provider.ProbeArtifactProviderError{
						Stage: "ok_anonym_login",
						Code:  "browser_post_preview_unsupported",
					},
				},
			},
		},
	}
	runnerCalled := false

	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
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
		t.Fatal("runner should not be created for post-preview unsupported provider resolution")
	}
	mustRebindPacket(t, cfg.ListenAddr)
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
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	err := Run(ctx, cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
			got = cfg
			return fakeRunner{
				run: func(ctx context.Context) error {
					if cfg.Hooks.OnReady != nil {
						cfg.Hooks.OnReady()
					}
					cancel()
					<-ctx.Done()
					return nil
				},
			}
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

func TestRunPassesExpandedTransportPlanToRunner(t *testing.T) {
	cfg := validClientConfig()
	cfg.Mode = config.TransportModeTCP
	cfg.UseDTLS = false
	cfg.BindInterface = "127.0.0.1"

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
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	err := Run(ctx, cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
			got = cfg
			return fakeRunner{
				run: func(ctx context.Context) error {
					if cfg.Hooks.OnReady != nil {
						cfg.Hooks.OnReady()
					}
					cancel()
					<-ctx.Done()
					return nil
				},
			}
		},
	})
	if err != nil {
		t.Fatalf("Run() error = %v", err)
	}
	if got.TURNMode != transport.TURNModeTCP {
		t.Fatalf("TURNMode = %s, want %s", got.TURNMode, transport.TURNModeTCP)
	}
	if got.PeerMode != transport.PeerModePlain {
		t.Fatalf("PeerMode = %s, want %s", got.PeerMode, transport.PeerModePlain)
	}
	if got.BindIP == nil || got.BindIP.String() != "127.0.0.1" {
		t.Fatalf("BindIP = %v, want 127.0.0.1", got.BindIP)
	}
}

func TestRunStartsConfiguredWorkersUnderSupervision(t *testing.T) {
	cfg := validClientConfig()
	cfg.Connections = 3
	cfg.ListenAddr = reserveUDPAddr(t)

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

	readyCh := make(chan int, cfg.Connections)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() {
		errCh <- Run(ctx, cfg, Dependencies{
			Registry: provider.NewRegistry(adapter),
			Logger:   testLogger(),
			NewRunner: func(cfg transport.ClientConfig) transport.Runner {
				return fakeRunner{
					run: func(ctx context.Context) error {
						if cfg.Outbound == nil || cfg.Inbound == nil {
							t.Errorf("worker %d missing supervised transport hooks", cfg.WorkerIndex)
						}
						if cfg.Hooks.OnReady != nil {
							cfg.Hooks.OnReady()
						}
						select {
						case readyCh <- cfg.WorkerIndex:
						case <-ctx.Done():
						}
						<-ctx.Done()
						return nil
					},
				}
			},
		})
	}()

	got := make([]int, 0, cfg.Connections)
	deadline := time.After(2 * time.Second)
	for len(got) < cfg.Connections {
		select {
		case worker := <-readyCh:
			got = append(got, worker)
		case <-deadline:
			t.Fatalf("timed out waiting for %d workers, got %v", cfg.Connections, got)
		}
	}
	sort.Ints(got)
	for index, worker := range got {
		if worker != index {
			t.Fatalf("worker index %d = %d, want %d", index, worker, index)
		}
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Run() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Run() did not stop after cancellation")
	}

	mustRebindPacket(t, cfg.ListenAddr)
}

func TestRunGeneratesSingleSessionIDAcrossWorkers(t *testing.T) {
	cfg := validClientConfig()
	cfg.Connections = 2
	cfg.ListenAddr = reserveUDPAddr(t)

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

	handler := newCaptureHandler()
	logger := slog.New(handler)
	workerLogged := make(chan struct{}, cfg.Connections)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() {
		errCh <- Run(ctx, cfg, Dependencies{
			Registry: provider.NewRegistry(adapter),
			Logger:   logger,
			NewRunner: func(cfg transport.ClientConfig) transport.Runner {
				return fakeRunner{
					run: func(ctx context.Context) error {
						cfg.Logger.Info("worker log", "worker", cfg.WorkerIndex)
						if cfg.Hooks.OnReady != nil {
							cfg.Hooks.OnReady()
						}
						select {
						case workerLogged <- struct{}{}:
						case <-ctx.Done():
						}
						<-ctx.Done()
						return nil
					},
				}
			},
		})
	}()

	for i := 0; i < cfg.Connections; i++ {
		select {
		case <-workerLogged:
		case <-time.After(2 * time.Second):
			t.Fatalf("timed out waiting for worker log %d", i)
		}
	}
	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Run() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Run() did not stop after cancellation")
	}

	records := handler.records()
	if len(records) == 0 {
		t.Fatal("expected captured logs")
	}

	var sessionID string
	workerLogs := 0
	for _, record := range records {
		value, ok := record.attrs["session_id"]
		if !ok {
			t.Fatalf("record %q missing session_id: %#v", record.message, record.attrs)
		}
		id := sessionIDValueString(value)
		if id == "" {
			t.Fatalf("record %q has invalid session_id: %#v", record.message, value)
		}
		if sessionID == "" {
			sessionID = id
		} else if sessionID != id {
			t.Fatalf("session_id mismatch: got %q want %q", id, sessionID)
		}
		if record.message == "worker log" {
			workerLogs++
		}
	}
	if workerLogs != cfg.Connections {
		t.Fatalf("worker log count = %d, want %d", workerLogs, cfg.Connections)
	}
}

func TestRunFailsSessionOnWorkerStartupError(t *testing.T) {
	cfg := validClientConfig()
	cfg.Connections = 2
	cfg.ListenAddr = reserveUDPAddr(t)

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

	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(adapter),
		Logger:   testLogger(),
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{
				run: func(ctx context.Context) error {
					if cfg.WorkerIndex == 0 {
						if cfg.Hooks.OnReady != nil {
							cfg.Hooks.OnReady()
						}
						<-ctx.Done()
						return nil
					}

					return runstage.Wrap(runstage.TURNDial, errors.New("turn dial failed"))
				},
			}
		},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.TURNDial {
		t.Fatalf("unexpected stage: %v", err)
	}

	mustRebindPacket(t, cfg.ListenAddr)
}

func TestRunRestartsReadyWorker(t *testing.T) {
	cfg := validClientConfig()
	cfg.ListenAddr = reserveUDPAddr(t)

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

	var attemptsMu sync.Mutex
	attempts := 0
	readyCh := make(chan int, 2)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() {
		errCh <- Run(ctx, cfg, Dependencies{
			Registry:          provider.NewRegistry(adapter),
			Logger:            testLogger(),
			RestartBackoff:    time.Millisecond,
			MaxWorkerRestarts: 1,
			NewRunner: func(cfg transport.ClientConfig) transport.Runner {
				attemptsMu.Lock()
				attempt := attempts
				attempts++
				attemptsMu.Unlock()

				return fakeRunner{
					run: func(ctx context.Context) error {
						if cfg.Hooks.OnReady != nil {
							cfg.Hooks.OnReady()
						}
						select {
						case readyCh <- attempt:
						case <-ctx.Done():
						}
						if attempt == 0 {
							return runstage.Wrap(runstage.ForwardingLoop, errors.New("forwarding failed"))
						}

						<-ctx.Done()
						return nil
					},
				}
			},
		})
	}()

	for want := 0; want < 2; want++ {
		select {
		case got := <-readyCh:
			if got != want {
				t.Fatalf("ready attempt = %d, want %d", got, want)
			}
		case <-time.After(2 * time.Second):
			t.Fatalf("timed out waiting for ready attempt %d", want)
		}
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Run() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Run() did not stop after cancellation")
	}
}

func TestRunFailsAfterRestartBudgetExhausted(t *testing.T) {
	cfg := validClientConfig()
	cfg.ListenAddr = reserveUDPAddr(t)

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

	err := Run(context.Background(), cfg, Dependencies{
		Registry:          provider.NewRegistry(adapter),
		Logger:            testLogger(),
		RestartBackoff:    time.Millisecond,
		MaxWorkerRestarts: 1,
		NewRunner: func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{
				run: func(context.Context) error {
					if cfg.Hooks.OnReady != nil {
						cfg.Hooks.OnReady()
					}

					return runstage.Wrap(runstage.ForwardingLoop, errors.New("forwarding failed"))
				},
			}
		},
	})
	if err == nil {
		t.Fatal("expected error")
	}
	stage, ok := runstage.FromError(err)
	if !ok || stage != runstage.SessionSupervise {
		t.Fatalf("unexpected stage: %v", err)
	}

	mustRebindPacket(t, cfg.ListenAddr)
}

func TestRunObservabilityEmitsStructuredEventsAndMetrics(t *testing.T) {
	cfg := validClientConfig()
	cfg.Provider = "generic-turn"
	cfg.ListenAddr = reserveUDPAddr(t)

	adapter := &fakeAdapter{
		name: "generic-turn",
		resolution: provider.Resolution{
			Credentials: provider.Credentials{
				Username: "turn-user",
				Password: "turn-pass",
				Address:  "turn.example.test:3478",
			},
			Metadata: map[string]string{
				"resolution_method": "static_link",
			},
		},
	}

	handler := newCaptureHandler()
	metrics := observe.NewMetrics()
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	errCh := make(chan error, 1)
	go func() {
		errCh <- Run(ctx, cfg, Dependencies{
			Registry: provider.NewRegistry(adapter),
			Logger:   slog.New(handler),
			Metrics:  metrics,
			NewRunner: func(cfg transport.ClientConfig) transport.Runner {
				return fakeRunner{
					run: func(ctx context.Context) error {
						if cfg.Hooks.OnReady != nil {
							cfg.Hooks.OnReady()
						}
						if cfg.Hooks.OnTraffic != nil {
							cfg.Hooks.OnTraffic(transport.TrafficDirectionLocalToRelay, 7)
							cfg.Hooks.OnTraffic(transport.TrafficDirectionRelayToLocal, 5)
						}
						<-ctx.Done()
						return nil
					},
				}
			},
		})
	}()

	deadline := time.After(2 * time.Second)
	for {
		if hasRecord(handler.records(), "runtime_ready") {
			break
		}
		select {
		case <-deadline:
			t.Fatal("timed out waiting for runtime_ready event")
		case <-time.After(10 * time.Millisecond):
		}
	}

	cancel()
	select {
	case err := <-errCh:
		if err != nil {
			t.Fatalf("Run() error = %v", err)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("Run() did not stop after cancellation")
	}

	records := handler.records()
	for _, event := range []string{"runtime_startup", "provider_resolution", "runtime_ready", "runtime_stop"} {
		record := findRecord(t, records, event)
		for _, key := range []string{"runtime", "session_id", "provider", "turn_mode", "peer_mode", "event", "stage", "result"} {
			if _, ok := record.attrs[key]; !ok {
				t.Fatalf("record %q missing %q: %#v", event, key, record.attrs)
			}
		}
	}

	text := metrics.Prometheus()
	for _, expected := range []string{
		"vk_turn_proxy_runtime_session_starts_total",
		`provider="generic-turn"`,
		`turn_mode="udp"`,
		`peer_mode="dtls"`,
		"vk_turn_proxy_runtime_active_workers",
		`vk_turn_proxy_runtime_forwarded_packets_total{direction="local_to_relay",provider="generic-turn",runtime="client"} 1`,
		`vk_turn_proxy_runtime_forwarded_bytes_total{direction="relay_to_local",provider="generic-turn",runtime="client"} 5`,
	} {
		if !strings.Contains(text, expected) {
			t.Fatalf("metrics output missing %q:\n%s", expected, text)
		}
	}
}

func TestRunObservabilityRedactsFailureError(t *testing.T) {
	cfg := validClientConfig()
	cfg.Provider = "vk"

	handler := newCaptureHandler()
	metrics := observe.NewMetrics()
	err := Run(context.Background(), cfg, Dependencies{
		Registry: provider.NewRegistry(&fakeAdapter{
			name: "vk",
			err:  errors.New("resolve https://vk.com/call/join/secret-token generic-turn://alice:s3cret@turn.example.test:3478 access_token=real-token"),
		}),
		Logger:  slog.New(handler),
		Metrics: metrics,
	})
	if err == nil {
		t.Fatal("expected error")
	}

	record := findRecord(t, handler.records(), "runtime_failure")
	errorText, _ := record.attrs["error"].(string)
	for _, secret := range []string{"secret-token", "alice", "s3cret", "real-token"} {
		if strings.Contains(errorText, secret) {
			t.Fatalf("runtime_failure leaked %q: %s", secret, errorText)
		}
	}
	if !strings.Contains(metrics.Prometheus(), `stage="provider_resolve"`) {
		t.Fatalf("metrics output missing provider_resolve failure:\n%s", metrics.Prometheus())
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

type fakeRuntimeChallenge struct {
	provider string
	stage    string
	kind     string
	prompt   string
	openURL  string
}

func (f fakeRuntimeChallenge) ProviderName() string { return f.provider }
func (f fakeRuntimeChallenge) StageName() string    { return f.stage }
func (f fakeRuntimeChallenge) Kind() string         { return f.kind }
func (f fakeRuntimeChallenge) Prompt() string       { return f.prompt }
func (f fakeRuntimeChallenge) OpenURL() string      { return f.openURL }
func (f fakeRuntimeChallenge) CookieURLs() []string { return []string{"https://api.vk.ru/"} }

func sessionIDValueString(value any) string {
	switch id := value.(type) {
	case string:
		return id
	case ID:
		return string(id)
	default:
		return ""
	}
}

func hasRecord(records []capturedRecord, message string) bool {
	for _, record := range records {
		if record.message == message {
			return true
		}
	}

	return false
}

func findRecord(t *testing.T, records []capturedRecord, message string) capturedRecord {
	t.Helper()
	for _, record := range records {
		if record.message == message {
			return record
		}
	}

	t.Fatalf("missing record %q in %#v", message, records)
	return capturedRecord{}
}

type capturedRecord struct {
	message string
	attrs   map[string]any
}

type captureHandler struct {
	state *captureState
	attrs []slog.Attr
}

type captureState struct {
	mu   sync.Mutex
	logs []capturedRecord
}

func newCaptureHandler() *captureHandler {
	return &captureHandler{
		state: &captureState{},
	}
}

func (h *captureHandler) Enabled(context.Context, slog.Level) bool {
	return true
}

func (h *captureHandler) Handle(_ context.Context, record slog.Record) error {
	attrs := make(map[string]any, len(h.attrs)+record.NumAttrs())
	for _, attr := range h.attrs {
		attrs[attr.Key] = attr.Value.Any()
	}
	record.Attrs(func(attr slog.Attr) bool {
		attrs[attr.Key] = attr.Value.Any()
		return true
	})

	h.state.mu.Lock()
	defer h.state.mu.Unlock()
	h.state.logs = append(h.state.logs, capturedRecord{
		message: record.Message,
		attrs:   attrs,
	})

	return nil
}

func (h *captureHandler) WithAttrs(attrs []slog.Attr) slog.Handler {
	return &captureHandler{
		state: h.state,
		attrs: append(append([]slog.Attr(nil), h.attrs...), attrs...),
	}
}

func (h *captureHandler) WithGroup(string) slog.Handler {
	return h
}

func (h *captureHandler) records() []capturedRecord {
	h.state.mu.Lock()
	defer h.state.mu.Unlock()

	out := make([]capturedRecord, len(h.state.logs))
	copy(out, h.state.logs)
	return out
}
