package clientcontrol

import (
	"context"
	"io"
	"log/slog"
	"net"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type fakeAdapter struct {
	name    string
	resolve func(context.Context, string) (provider.Resolution, error)
}

func (a fakeAdapter) Name() string { return a.name }

func (a fakeAdapter) Resolve(ctx context.Context, link string) (provider.Resolution, error) {
	return a.resolve(ctx, link)
}

type fakeRunner struct {
	run func(context.Context) error
}

func (r fakeRunner) Run(ctx context.Context) error {
	return r.run(ctx)
}

type fakeChallenge struct {
	provider string
	stage    string
	kind     string
	prompt   string
	openURL  string
}

func (f fakeChallenge) ProviderName() string { return f.provider }
func (f fakeChallenge) StageName() string    { return f.stage }
func (f fakeChallenge) Kind() string         { return f.kind }
func (f fakeChallenge) Prompt() string       { return f.prompt }
func (f fakeChallenge) OpenURL() string      { return f.openURL }
func (f fakeChallenge) CookieURLs() []string { return []string{"https://api.vk.ru/"} }

type fakeContinuation struct {
	result *provider.BrowserContinuation
	err    error
}

func (c fakeContinuation) Complete(context.Context) (*provider.BrowserContinuation, error) {
	if c.err != nil {
		return nil, c.err
	}
	return c.result, nil
}

func (c fakeContinuation) Close() error { return nil }

func TestHostInfoExposesContractVersionAndBuildIdentity(t *testing.T) {
	host := New(WithBuildIdentity(testBuildIdentity()))

	info := host.Info()
	if info.ContractVersion != ContractVersion {
		t.Fatalf("contract_version = %q, want %q", info.ContractVersion, ContractVersion)
	}
	if info.Version != ContractVersion {
		t.Fatalf("version alias = %q, want %q", info.Version, ContractVersion)
	}
	if info.Build.Version != "0.1.0" {
		t.Fatalf("build version = %q, want 0.1.0", info.Build.Version)
	}
	if info.Build.BuildNumber != "1" {
		t.Fatalf("build number = %q, want 1", info.Build.BuildNumber)
	}
	if !containsCapability(info.Capabilities, CapabilityPlatformTunnels) {
		t.Fatalf("capabilities = %v, want platform_tunnels", info.Capabilities)
	}
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	if info.PlatformTunnels[0].Mode != PlatformTunnelModeLinuxTun {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", info.PlatformTunnels[0].Mode, PlatformTunnelModeLinuxTun)
	}
	if info.PlatformTunnels[0].Available {
		t.Fatal("platform_tunnels[0].available = true, want false")
	}
	if info.PlatformTunnels[0].MissingPrerequisite != PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf("platform_tunnels[0].missing_prerequisite = %q, want %q", info.PlatformTunnels[0].MissingPrerequisite, PlatformTunnelPrerequisiteHostImplementation)
	}
}

func TestHostNegotiateRejectsIncompatibleVersionAndCapability(t *testing.T) {
	host := New()

	if _, err := host.Negotiate(NegotiateRequest{
		SupportedVersions: []string{"99"},
	}); err == nil {
		t.Fatal("expected incompatible version error")
	}

	if _, err := host.Negotiate(NegotiateRequest{
		SupportedVersions:    []string{ContractVersion},
		RequiredCapabilities: []Capability{"custom_capability"},
	}); err == nil {
		t.Fatal("expected missing capability error")
	}

	if _, err := host.Negotiate(NegotiateRequest{
		SupportedVersions:    []string{ContractVersion},
		RequiredCapabilities: []Capability{CapabilityPlatformTunnels},
	}); err != nil {
		t.Fatalf("Negotiate(platform_tunnels) error = %v", err)
	}
}

func TestHostStartPlatformTunnelFailsClosedByDefault(t *testing.T) {
	host := New(WithBuildIdentity(testBuildIdentity()))

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeLinuxTun,
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.Ready {
		t.Fatal("StartPlatformTunnel().Ready = true, want false")
	}
	if result.Stage != PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("StartPlatformTunnel().Stage = %q, want %q", result.Stage, PlatformTunnelStartupStageCapabilityCheck)
	}
	if result.MissingPrerequisite != PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf("StartPlatformTunnel().MissingPrerequisite = %q, want %q", result.MissingPrerequisite, PlatformTunnelPrerequisiteHostImplementation)
	}
}

func TestHostNormalizesInvalidPlatformTunnelCapabilitiesToFailClosedDefault(t *testing.T) {
	host := New(
		WithBuildIdentity(testBuildIdentity()),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{{
			Mode:      PlatformTunnelMode("future_linux_mode"),
			Available: true,
		}}),
	)

	info := host.Info()
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	if info.PlatformTunnels[0].Mode != PlatformTunnelModeLinuxTun {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", info.PlatformTunnels[0].Mode, PlatformTunnelModeLinuxTun)
	}
	if info.PlatformTunnels[0].Available {
		t.Fatal("platform_tunnels[0].available = true, want false")
	}
	if info.PlatformTunnels[0].MissingPrerequisite != PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf("platform_tunnels[0].missing_prerequisite = %q, want %q", info.PlatformTunnels[0].MissingPrerequisite, PlatformTunnelPrerequisiteHostImplementation)
	}
}

func TestHostNormalizesAvailablePlatformTunnelWithoutSatisfiedPrerequisitesToFailClosedDefault(t *testing.T) {
	host := New(
		WithBuildIdentity(testBuildIdentity()),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{{
			Mode:      PlatformTunnelModeLinuxTun,
			Available: true,
		}}),
	)

	info := host.Info()
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	if info.PlatformTunnels[0].Mode != PlatformTunnelModeLinuxTun {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", info.PlatformTunnels[0].Mode, PlatformTunnelModeLinuxTun)
	}
	if info.PlatformTunnels[0].Available {
		t.Fatal("platform_tunnels[0].available = true, want false")
	}
	if info.PlatformTunnels[0].MissingPrerequisite != PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf("platform_tunnels[0].missing_prerequisite = %q, want %q", info.PlatformTunnels[0].MissingPrerequisite, PlatformTunnelPrerequisiteHostImplementation)
	}
}

func TestHostStartPlatformTunnelRejectsInvalidStartupResult(t *testing.T) {
	host := New(
		WithBuildIdentity(testBuildIdentity()),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{{
			Mode:      PlatformTunnelModeLinuxTun,
			Available: true,
			SatisfiedPrerequisites: []PlatformTunnelPrerequisite{
				PlatformTunnelPrerequisiteRouteExclusion,
			},
		}}),
		WithPlatformTunnelStarter(func(_ context.Context, req PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			return PlatformTunnelStartResult{
				Mode:  req.Mode,
				Ready: false,
			}, nil
		}),
	)

	if _, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeLinuxTun,
	}); err == nil {
		t.Fatal("StartPlatformTunnel() error = nil, want invalid startup result error")
	} else if !strings.Contains(err.Error(), "invalid platform tunnel startup result") {
		t.Fatalf("StartPlatformTunnel() error = %v, want invalid startup result", err)
	}
}

func TestHostStartPlatformTunnelRejectsStartupResultWithoutMissingPrerequisite(t *testing.T) {
	host := New(
		WithBuildIdentity(testBuildIdentity()),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{{
			Mode:      PlatformTunnelModeLinuxTun,
			Available: true,
			SatisfiedPrerequisites: []PlatformTunnelPrerequisite{
				PlatformTunnelPrerequisiteRouteExclusion,
			},
		}}),
		WithPlatformTunnelStarter(func(_ context.Context, req PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			return PlatformTunnelStartResult{
				Mode:    req.Mode,
				Ready:   false,
				Stage:   PlatformTunnelStartupStageRuntimeAttach,
				Message: "runtime attach failed without a typed prerequisite",
			}, nil
		}),
	)

	if _, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeLinuxTun,
	}); err == nil {
		t.Fatal("StartPlatformTunnel() error = nil, want invalid startup result error")
	} else if !strings.Contains(err.Error(), "missing_prerequisite") {
		t.Fatalf("StartPlatformTunnel() error = %v, want missing_prerequisite validation", err)
	}
}

func TestHostStartsReadySessionAndExportsDiagnostics(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		WithSessionIDSource(func() string { return "session-ready" }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "generic-turn",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
					Metadata: map[string]string{
						"resolution_method": "static_link",
					},
				}, nil
			},
		})),
		withRunnerFactory(func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{run: func(ctx context.Context) error {
				if cfg.Hooks.OnReady != nil {
					cfg.Hooks.OnReady()
				}
				if cfg.Hooks.OnTraffic != nil {
					cfg.Hooks.OnTraffic(transport.TrafficDirectionLocalToRelay, 11)
				}
				<-ctx.Done()
				return nil
			}}
		}),
	)

	events, cancel := host.Subscribe(16)
	defer cancel()

	sessionState, err := host.StartSession(context.Background(), StartSessionRequest{
		Spec: &ProfileSpec{
			Provider:    "generic-turn",
			Link:        "generic-turn://user:pass@turn.example.test:3478",
			ListenAddr:  reserveUDPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(true),
		},
	})
	if err != nil {
		t.Fatalf("StartSession() error = %v", err)
	}
	if sessionState.ID != "session-ready" {
		t.Fatalf("session id = %q, want session-ready", sessionState.ID)
	}

	readyEvent := waitForEvent(t, events, EventSessionReady)
	if readyEvent.SessionID != sessionState.ID {
		t.Fatalf("ready event session_id = %q, want %q", readyEvent.SessionID, sessionState.ID)
	}

	if _, err := host.StopSession(sessionState.ID); err != nil {
		t.Fatalf("StopSession() error = %v", err)
	}
	finalState, err := host.WaitSession(context.Background(), sessionState.ID)
	if err != nil {
		t.Fatalf("WaitSession() error = %v", err)
	}
	if finalState.State != SessionStateStopped {
		t.Fatalf("final state = %q, want stopped", finalState.State)
	}

	diagnostics, err := host.ExportDiagnostics(sessionState.ID)
	if err != nil {
		t.Fatalf("ExportDiagnostics() error = %v", err)
	}
	if len(diagnostics.Events) == 0 {
		t.Fatal("expected diagnostics events")
	}
	if !strings.Contains(diagnostics.Metrics, "vk_turn_proxy_runtime_session_starts_total") {
		t.Fatalf("diagnostics metrics missing session starts:\n%s", diagnostics.Metrics)
	}
	if diagnostics.ContractVersion != ContractVersion {
		t.Fatalf("diagnostics contract_version = %q, want %q", diagnostics.ContractVersion, ContractVersion)
	}
	if diagnostics.HostBuild.Version != "0.1.0" {
		t.Fatalf("diagnostics host build version = %q, want 0.1.0", diagnostics.HostBuild.Version)
	}
}

func TestHostStartSessionRejectsUnsupportedPolicyBeforeSessionCreation(t *testing.T) {
	host := New(WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))))

	testCases := []ProfileSpec{
		{
			Provider:      "generic-turn",
			Link:          "generic-turn://user:pass@turn.example.test:3478",
			ListenAddr:    reserveUDPAddr(t),
			PeerAddr:      "127.0.0.1:56000",
			Connections:   1,
			Mode:          TransportModeAuto,
			UseDTLS:       boolRef(true),
			BindInterface: "eth0",
		},
		{
			Provider:    "generic-turn",
			Link:        "generic-turn://user:pass@turn.example.test:3478",
			ListenAddr:  reserveTCPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Ingress:     AdapterTCP,
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(false),
		},
	}

	for _, spec := range testCases {
		if _, err := host.StartSession(context.Background(), StartSessionRequest{Spec: &spec}); err == nil {
			t.Fatalf("StartSession(%+v) succeeded, want error", spec)
		}
	}

	if sessions := host.Sessions(); len(sessions) != 0 {
		t.Fatalf("Sessions() = %d, want 0 after rejected policy", len(sessions))
	}
}

func TestHostSurfacesChallengeAndContinuesToReady(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithSessionIDSource(func() string { return "session-challenge" }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				handler := provider.BrowserContinuationHandlerFromContext(ctx)
				if handler == nil {
					return provider.Resolution{}, io.ErrUnexpectedEOF
				}
				if _, err := handler.Continue(ctx, fakeChallenge{
					provider: "vk",
					stage:    "vk_calls_get_anonymous_token",
					kind:     "captcha",
					prompt:   "complete captcha",
					openURL:  "https://example.test/challenge",
				}); err != nil {
					return provider.Resolution{}, err
				}
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
					Metadata: map[string]string{
						"resolution_method": "browser_continuation",
					},
				}, nil
			},
		})),
		withRunnerFactory(func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{run: func(ctx context.Context) error {
				if cfg.Hooks.OnReady != nil {
					cfg.Hooks.OnReady()
				}
				<-ctx.Done()
				return nil
			}}
		}),
		withContinuationStarter(func(ctx context.Context, challenge provider.InteractiveChallenge) (browserContinuation, error) {
			return fakeContinuation{result: &provider.BrowserContinuation{}}, nil
		}),
	)

	events, cancel := host.Subscribe(16)
	defer cancel()

	sessionState, err := host.StartSession(context.Background(), StartSessionRequest{
		Spec: &ProfileSpec{
			Provider:            "vk",
			Link:                "https://vk.com/call/join/test-token",
			ListenAddr:          reserveUDPAddr(t),
			PeerAddr:            "127.0.0.1:56000",
			Connections:         1,
			Mode:                TransportModeAuto,
			UseDTLS:             boolRef(true),
			InteractiveProvider: true,
		},
	})
	if err != nil {
		t.Fatalf("StartSession() error = %v", err)
	}

	challengeEvent := waitForEvent(t, events, EventChallengeRequired)
	if challengeEvent.Challenge == nil {
		t.Fatal("challenge event missing challenge payload")
	}
	if challengeEvent.Challenge.SessionID != sessionState.ID {
		t.Fatalf("challenge session_id = %q, want %q", challengeEvent.Challenge.SessionID, sessionState.ID)
	}

	challenge, err := host.ContinueChallenge(challengeEvent.Challenge.ID)
	if err != nil {
		t.Fatalf("ContinueChallenge() error = %v", err)
	}
	if challenge.Status != ChallengeStatusContinuing {
		t.Fatalf("challenge status = %q, want continuing", challenge.Status)
	}

	updatedEvent := waitForEvent(t, events, EventChallengeUpdated)
	if updatedEvent.Challenge == nil {
		t.Fatal("challenge update missing payload")
	}
	readyEvent := waitForEvent(t, events, EventSessionReady)
	if readyEvent.SessionID != sessionState.ID {
		t.Fatalf("ready event session_id = %q, want %q", readyEvent.SessionID, sessionState.ID)
	}

	if _, err := host.StopSession(sessionState.ID); err != nil {
		t.Fatalf("StopSession() error = %v", err)
	}
	if _, err := host.WaitSession(context.Background(), sessionState.ID); err != nil {
		t.Fatalf("WaitSession() error = %v", err)
	}
}

func TestHostRejectsSessionIDAllocationCollision(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithSessionIDSource(func() string { return "fixed-session" }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "generic-turn",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
				}, nil
			},
		})),
		withRunnerFactory(func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{run: func(ctx context.Context) error {
				<-ctx.Done()
				return nil
			}}
		}),
	)

	first, err := host.StartSession(context.Background(), StartSessionRequest{
		Spec: &ProfileSpec{
			Provider:    "generic-turn",
			Link:        "generic-turn://user:pass@turn.example.test:3478",
			ListenAddr:  reserveUDPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(true),
		},
	})
	if err != nil {
		t.Fatalf("first StartSession() error = %v", err)
	}
	t.Cleanup(func() {
		_, _ = host.StopSession(first.ID)
		_, _ = host.WaitSession(context.Background(), first.ID)
	})

	if _, err := host.StartSession(context.Background(), StartSessionRequest{
		Spec: &ProfileSpec{
			Provider:    "generic-turn",
			Link:        "generic-turn://user:pass@turn.example.test:3478",
			ListenAddr:  reserveUDPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(true),
		},
	}); err == nil {
		t.Fatal("expected session id allocation failure")
	}
}

func waitForEvent(t *testing.T, events <-chan Event, eventType EventType) Event {
	t.Helper()
	deadline := time.After(3 * time.Second)
	for {
		select {
		case <-deadline:
			t.Fatalf("timed out waiting for %s", eventType)
		case event := <-events:
			if event.Type == eventType {
				return event
			}
		}
	}
}

func testBuildIdentity() BuildIdentity {
	return BuildIdentity{
		Product:     "vk-turn-proxy-go",
		Version:     "0.1.0",
		BuildNumber: "1",
		Revision:    "deadbeefcafe",
		Dirty:       true,
		BuiltAt:     "2026-04-07T12:00:00Z",
		Role:        "clientd",
		Target:      "linux/amd64",
	}
}

func waitForSessionState(t *testing.T, host *Host, sessionID string, want SessionState) Session {
	t.Helper()
	deadline := time.After(3 * time.Second)
	for {
		sessionState, err := host.Session(sessionID)
		if err != nil {
			t.Fatalf("Session() error = %v", err)
		}
		if sessionState.State == want {
			return sessionState
		}
		select {
		case <-deadline:
			t.Fatalf("timed out waiting for session %s state %s; got %s", sessionID, want, sessionState.State)
		case <-time.After(10 * time.Millisecond):
		}
	}
}

func reserveUDPAddr(t *testing.T) string {
	t.Helper()
	conn, err := net.ListenPacket("udp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("ListenPacket() error = %v", err)
	}
	defer conn.Close()
	return conn.LocalAddr().String()
}

func reserveTCPAddr(t *testing.T) string {
	t.Helper()
	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("Listen() error = %v", err)
	}
	defer listener.Close()
	return listener.Addr().String()
}

func boolRef(value bool) *bool {
	out := value
	return &out
}

func containsCapability(caps []Capability, want Capability) bool {
	for _, cap := range caps {
		if cap == want {
			return true
		}
	}
	return false
}
