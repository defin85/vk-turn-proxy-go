package clientcontrol

import (
	"context"
	"encoding/json"
	"errors"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

type fakeAdapter struct {
	name       string
	descriptor provider.ProviderDescriptor
	resolve    func(context.Context, string) (provider.Resolution, error)
}

func (a fakeAdapter) Name() string { return a.name }

func (a fakeAdapter) Descriptor() provider.ProviderDescriptor {
	if a.descriptor.ID != "" {
		return a.descriptor
	}

	return provider.ProviderDescriptor{
		ID:            a.name,
		DisplayName:   a.name,
		InputKind:     provider.ProviderInputKindLink,
		AuthPosture:   provider.ProviderAuthPostureNotApplicable,
		BrowserPolicy: provider.ProviderBrowserPolicyNotRequired,
		ArtifactFamilies: []provider.ArtifactFamily{
			provider.ArtifactFamilyGenericTURN,
		},
		CapabilityHints: provider.ProviderCapabilityHints{
			PotentialActions: []provider.ArtifactAction{
				provider.ArtifactActionStartOnThisDevice,
				provider.ArtifactActionExportHandoff,
			},
			RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
		},
	}
}

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
	metadata provider.InteractiveChallengeMetadata
}

func (f fakeChallenge) ProviderName() string { return f.provider }
func (f fakeChallenge) StageName() string    { return f.stage }
func (f fakeChallenge) Kind() string         { return f.kind }
func (f fakeChallenge) Prompt() string       { return f.prompt }
func (f fakeChallenge) OpenURL() string      { return f.openURL }
func (f fakeChallenge) CookieURLs() []string { return []string{"https://api.vk.ru/"} }
func (f fakeChallenge) ChallengeMetadata() provider.InteractiveChallengeMetadata {
	return f.metadata
}

type fakeOwnedBrowserChallenge struct {
	fakeChallenge
	cookieURLs    []string
	stageRequests []provider.BrowserStageRequest
}

func (f fakeOwnedBrowserChallenge) CookieURLs() []string {
	return append([]string(nil), f.cookieURLs...)
}

func (f fakeOwnedBrowserChallenge) BrowserStageRequests() []provider.BrowserStageRequest {
	if len(f.stageRequests) == 0 {
		return nil
	}

	out := make([]provider.BrowserStageRequest, 0, len(f.stageRequests))
	for _, request := range f.stageRequests {
		cloned := provider.BrowserStageRequest{
			Stage:  request.Stage,
			Method: request.Method,
			URL:    request.URL,
		}
		if len(request.Form) > 0 {
			cloned.Form = make(map[string]string, len(request.Form))
			for key, value := range request.Form {
				cloned.Form[key] = value
			}
		}
		out = append(out, cloned)
	}
	return out
}

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
	if !containsCapability(info.Capabilities, CapabilityProviderConfigs) {
		t.Fatalf("capabilities = %v, want provider_configs", info.Capabilities)
	}
	if !containsCapability(info.Capabilities, CapabilityProviderRuntimeArtifacts) {
		t.Fatalf("capabilities = %v, want provider-runtime-artifacts", info.Capabilities)
	}
	if !containsCapability(info.Capabilities, CapabilityRuntimeExecutionPlanning) {
		t.Fatalf("capabilities = %v, want runtime-execution-planning", info.Capabilities)
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

func TestHostProvidersExposeSortedDescriptorCatalog(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(
			fakeAdapter{
				name: "zeta",
				descriptor: provider.ProviderDescriptor{
					ID:               "zeta",
					DisplayName:      "Zeta",
					InputKind:        provider.ProviderInputKindLink,
					AuthPosture:      provider.ProviderAuthPostureAccount,
					BrowserPolicy:    provider.ProviderBrowserPolicyExternalRequired,
					ChallengeModes:   []provider.ProviderChallengeMode{provider.ProviderChallengeModeBrowser},
					ArtifactFamilies: []provider.ArtifactFamily{provider.ArtifactFamilyConferenceRoom},
					CapabilityHints: provider.ProviderCapabilityHints{
						PotentialActions: []provider.ArtifactAction{provider.ArtifactActionOpenRoom},
					},
				},
			},
			fakeAdapter{
				name: "alpha",
				descriptor: provider.ProviderDescriptor{
					ID:               "alpha",
					DisplayName:      "Alpha",
					InputKind:        provider.ProviderInputKindLink,
					AuthPosture:      provider.ProviderAuthPostureStaticSecret,
					BrowserPolicy:    provider.ProviderBrowserPolicyNotRequired,
					ArtifactFamilies: []provider.ArtifactFamily{provider.ArtifactFamilyGenericTURN},
					CapabilityHints: provider.ProviderCapabilityHints{
						PotentialActions: []provider.ArtifactAction{provider.ArtifactActionExportHandoff},
					},
				},
			},
		)),
	)

	descriptors := host.Providers()
	if len(descriptors) != 2 {
		t.Fatalf("Providers() len = %d, want 2", len(descriptors))
	}
	if descriptors[0].ID != "alpha" || descriptors[1].ID != "zeta" {
		t.Fatalf("Providers() order = %+v, want alpha,zeta", descriptors)
	}

	descriptors[0].ArtifactFamilies[0] = ArtifactFamilyCameraStream
	again := host.Providers()
	if len(again[0].ArtifactFamilies) != 1 || again[0].ArtifactFamilies[0] != ArtifactFamilyGenericTURN {
		t.Fatalf("Providers() mutated internal descriptor state: %+v", again[0])
	}
}

func TestHostProvidersExposeProviderSettingsSchema(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
		})),
	)

	descriptors := host.Providers()
	if len(descriptors) != 1 {
		t.Fatalf("Providers() len = %d, want 1", len(descriptors))
	}
	if descriptors[0].SettingsSchema == nil {
		t.Fatal("provider settings schema missing from provider catalog")
	}
	if descriptors[0].SettingsSchema.Type != "object" {
		t.Fatalf("provider settings schema type = %q, want object", descriptors[0].SettingsSchema.Type)
	}
	if got := descriptors[0].SettingsSchema.Properties["region"].Title; got != "Region" {
		t.Fatalf("provider settings schema region title = %q, want Region", got)
	}

	descriptors[0].SettingsSchema.Properties["region"] = ProviderSettingProperty{
		Type:  ProviderSettingTypeString,
		Title: "Mutated",
	}
	again := host.Providers()
	if got := again[0].SettingsSchema.Properties["region"].Title; got != "Region" {
		t.Fatalf("provider settings schema clone mutated unexpectedly: %q", got)
	}
}

func TestHostProvidersOmitInvalidProviderSettingsSchema(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "invalid-schema-provider",
			descriptor: invalidProviderSettingsTestDescriptor("invalid-schema-provider"),
		})),
	)

	descriptors := host.Providers()
	if len(descriptors) != 1 {
		t.Fatalf("Providers() len = %d, want 1", len(descriptors))
	}
	if descriptors[0].SettingsSchema != nil {
		t.Fatalf("provider settings schema = %#v, want nil for invalid descriptor schema", descriptors[0].SettingsSchema)
	}
}

func TestHostUpsertProfileRejectsPromptOnlyProviderSettings(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
		})),
	)

	_, err := host.UpsertProfile(Profile{
		ID:   "profile-1",
		Name: "provider settings",
		Spec: ProfileSpec{
			Provider:         "schema-provider",
			Link:             "https://example.test/invite/abc",
			ProviderSettings: ProviderSettings{"region": "eu-west", "device_pin": "123456"},
			ListenAddr:       reserveUDPAddr(t),
			PeerAddr:         "127.0.0.1:56000",
			Connections:      1,
			Mode:             TransportModeAuto,
			UseDTLS:          boolRef(true),
		},
	})
	if err == nil {
		t.Fatal("UpsertProfile() expected provider settings persistence error")
	}

	var validationErr *ProviderSettingsValidationError
	if !errors.As(err, &validationErr) {
		t.Fatalf("UpsertProfile() error = %v, want ProviderSettingsValidationError", err)
	}
	if validationErr.Field != "device_pin" {
		t.Fatalf("validation field = %q, want device_pin", validationErr.Field)
	}
	if validationErr.Violation != providerSettingsViolationPersistence {
		t.Fatalf("validation violation = %q, want %q", validationErr.Violation, providerSettingsViolationPersistence)
	}
}

func TestHostProviderConfigLifecycle(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
		})),
		withNow(func() time.Time {
			return time.Date(2026, 4, 13, 10, 15, 0, 0, time.UTC)
		}),
	)

	saved, err := host.UpsertProviderConfig(ProviderConfig{
		Name:     "EU guest",
		Provider: "schema-provider",
		ProviderSettings: ProviderSettings{
			"region":       "eu-west",
			"device_index": 3,
		},
	})
	if err != nil {
		t.Fatalf("UpsertProviderConfig() error = %v", err)
	}
	if saved.ID == "" {
		t.Fatal("saved provider config id is empty")
	}
	if saved.Availability.State != ProviderConfigAvailabilityAvailable {
		t.Fatalf("saved availability = %q, want %q", saved.Availability.State, ProviderConfigAvailabilityAvailable)
	}
	if got := saved.ProviderSettings["device_index"]; got != int64(3) {
		t.Fatalf("saved provider setting device_index = %#v, want int64(3)", got)
	}

	listed := host.ProviderConfigs()
	if len(listed) != 1 {
		t.Fatalf("ProviderConfigs() len = %d, want 1", len(listed))
	}
	if listed[0].ID != saved.ID {
		t.Fatalf("listed provider config id = %q, want %q", listed[0].ID, saved.ID)
	}

	stored, err := host.ProviderConfig(saved.ID)
	if err != nil {
		t.Fatalf("ProviderConfig() error = %v", err)
	}
	if stored.Name != "EU guest" {
		t.Fatalf("ProviderConfig().Name = %q, want EU guest", stored.Name)
	}

	if err := host.DeleteProviderConfig(saved.ID); err != nil {
		t.Fatalf("DeleteProviderConfig() error = %v", err)
	}
	if _, err := host.ProviderConfig(saved.ID); !errors.Is(err, ErrProviderConfigNotFound) {
		t.Fatalf("ProviderConfig() after delete error = %v, want ErrProviderConfigNotFound", err)
	}
}

func TestHostProviderConfigRejectsPromptOnlySettings(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
		})),
	)

	_, err := host.UpsertProviderConfig(ProviderConfig{
		Name:     "Prompt-only",
		Provider: "schema-provider",
		ProviderSettings: ProviderSettings{
			"region":     "eu-west",
			"device_pin": "123456",
		},
	})
	if err == nil {
		t.Fatal("UpsertProviderConfig() expected provider settings persistence error")
	}

	var validationErr *ProviderSettingsValidationError
	if !errors.As(err, &validationErr) {
		t.Fatalf("UpsertProviderConfig() error = %v, want ProviderSettingsValidationError", err)
	}
	if validationErr.Field != "device_pin" {
		t.Fatalf("validation field = %q, want device_pin", validationErr.Field)
	}
	if validationErr.Violation != providerSettingsViolationPersistence {
		t.Fatalf("validation violation = %q, want %q", validationErr.Violation, providerSettingsViolationPersistence)
	}
}

func TestHostProviderConfigRejectsRestoreBypassOnOrdinaryUpsert(t *testing.T) {
	host := New(WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))))
	restoredAt := time.Date(2026, 4, 13, 10, 15, 0, 0, time.UTC)

	_, err := host.UpsertProviderConfig(ProviderConfig{
		ID:       "cfg-1",
		Name:     "Legacy WB config",
		Provider: "wb-stream",
		ProviderSettings: ProviderSettings{
			"region": "eu-west",
		},
		CreatedAt: restoredAt,
		UpdatedAt: restoredAt,
	})
	if err == nil {
		t.Fatal("UpsertProviderConfig() expected provider validation error")
	}
}

func TestHostProviderConfigRestoreKeepsUnavailableRecordExplicit(t *testing.T) {
	host := New(WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))))
	restoredAt := time.Date(2026, 4, 13, 10, 15, 0, 0, time.UTC)

	saved, err := host.RestoreProviderConfig(ProviderConfig{
		ID:       "cfg-1",
		Name:     "Legacy WB config",
		Provider: "wb-stream",
		ProviderSettings: ProviderSettings{
			"region":       "eu-west",
			"device_index": 2,
		},
		CreatedAt: restoredAt,
		UpdatedAt: restoredAt,
	})
	if err != nil {
		t.Fatalf("RestoreProviderConfig() error = %v", err)
	}
	if saved.Availability.State != ProviderConfigAvailabilityProviderUnavailable {
		t.Fatalf("saved availability = %q, want %q", saved.Availability.State, ProviderConfigAvailabilityProviderUnavailable)
	}
	if saved.Availability.Message == "" {
		t.Fatal("saved availability message is empty")
	}

	listed := host.ProviderConfigs()
	if len(listed) != 1 {
		t.Fatalf("ProviderConfigs() len = %d, want 1", len(listed))
	}
	if listed[0].Availability.State != ProviderConfigAvailabilityProviderUnavailable {
		t.Fatalf("listed availability = %q, want %q", listed[0].Availability.State, ProviderConfigAvailabilityProviderUnavailable)
	}
	if got := listed[0].ProviderSettings["region"]; got != "eu-west" {
		t.Fatalf("listed provider setting region = %#v, want eu-west", got)
	}
}

func TestHostUpsertProfileAllowsPersistedProfileWithoutSecretLink(t *testing.T) {
	host := New(WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))))

	profile, err := host.UpsertProfile(Profile{
		ID:   "profile-1",
		Name: "saved-vk-profile",
		Spec: ProfileSpec{
			Provider:            "vk",
			Link:                "",
			ListenAddr:          reserveUDPAddr(t),
			PeerAddr:            "127.0.0.1:56000",
			Connections:         4,
			Mode:                TransportModeUDP,
			UseDTLS:             boolRef(true),
			InteractiveProvider: true,
			LogLevel:            "info",
		},
	})
	if err != nil {
		t.Fatalf("UpsertProfile() error = %v", err)
	}
	if profile.Spec.Link != "" {
		t.Fatalf("persisted profile link = %q, want empty redacted value", profile.Spec.Link)
	}

	stored, err := host.Profile(profile.ID)
	if err != nil {
		t.Fatalf("Profile() error = %v", err)
	}
	if stored.Spec.Link != "" {
		t.Fatalf("stored profile link = %q, want empty redacted value", stored.Spec.Link)
	}

	if _, err := host.StartSession(context.Background(), StartSessionRequest{
		ProfileID: profile.ID,
	}); err == nil || !strings.Contains(err.Error(), "link is required") {
		t.Fatalf("StartSession(profile_id) error = %v, want link is required", err)
	}
	if sessions := host.Sessions(); len(sessions) != 0 {
		t.Fatalf("Sessions() = %d, want 0 after rejected runtime start", len(sessions))
	}
}

func TestHostStartResolutionPassesValidatedProviderSettingsThroughContext(t *testing.T) {
	settingsCh := make(chan provider.ProviderSettings, 1)
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				settingsCh <- provider.SettingsFromContext(ctx)
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
					Metadata: map[string]string{
						"provider":          "schema-provider",
						"resolution_method": "settings_test",
					},
				}, nil
			},
		})),
	)

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "schema-provider",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://example.test/invite/abc",
		},
		ProviderSettings: ProviderSettings{
			"region":       "eu-west",
			"device_pin":   "123456",
			"device_index": float64(3),
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}
	waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)

	select {
	case settings := <-settingsCh:
		if settings["region"] != "eu-west" {
			t.Fatalf("provider settings region = %#v, want eu-west", settings["region"])
		}
		if settings["device_pin"] != "123456" {
			t.Fatalf("provider settings device_pin = %#v, want 123456", settings["device_pin"])
		}
		index, ok := settings["device_index"].(int64)
		if !ok || index != 3 {
			t.Fatalf("provider settings device_index = %#v, want int64(3)", settings["device_index"])
		}
	case <-time.After(2 * time.Second):
		t.Fatal("timed out waiting for provider settings context")
	}
}

func TestHostStartResolutionRejectsProviderSettingsWhenDescriptorSchemaIsInvalid(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "invalid-schema-provider",
			descriptor: invalidProviderSettingsTestDescriptor("invalid-schema-provider"),
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{}, nil
			},
		})),
	)

	_, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "invalid-schema-provider",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://example.test/invite/abc",
		},
		ProviderSettings: ProviderSettings{
			"device_pin": "123456",
		},
	})
	if err == nil {
		t.Fatal("StartResolution() expected provider settings validation error")
	}

	var validationErr *ProviderSettingsValidationError
	if !errors.As(err, &validationErr) {
		t.Fatalf("StartResolution() error = %v, want ProviderSettingsValidationError", err)
	}
	if validationErr.Field != "device_pin" {
		t.Fatalf("validation field = %q, want device_pin", validationErr.Field)
	}
	if validationErr.Violation != providerSettingsViolationUnknown {
		t.Fatalf("validation violation = %q, want %q", validationErr.Violation, providerSettingsViolationUnknown)
	}
}

func TestHostStartSessionRedactsPromptOnlyProviderSettingsFromSnapshot(t *testing.T) {
	releaseCh := make(chan struct{})
	host := New(
		WithSessionIDSource(func() string { return "session-provider-settings" }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
					Metadata: map[string]string{
						"provider":          "schema-provider",
						"resolution_method": "settings_test",
					},
				}, nil
			},
		})),
		withRunnerFactory(func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{run: func(ctx context.Context) error {
				<-releaseCh
				return ctx.Err()
			}}
		}),
	)

	sessionState, err := host.StartSession(context.Background(), StartSessionRequest{
		Spec: &ProfileSpec{
			Provider: "schema-provider",
			Link:     "https://example.test/invite/abc",
			ProviderSettings: ProviderSettings{
				"region":       "eu-west",
				"device_pin":   "123456",
				"device_index": float64(3),
			},
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
	defer close(releaseCh)

	if sessionState.Profile.ProviderSettings == nil {
		t.Fatal("session snapshot provider settings missing")
	}
	if _, ok := sessionState.Profile.ProviderSettings["device_pin"]; ok {
		t.Fatalf("session snapshot leaked prompt-only provider setting: %+v", sessionState.Profile.ProviderSettings)
	}
	if got := sessionState.Profile.ProviderSettings["region"]; got != "eu-west" {
		t.Fatalf("session snapshot region = %#v, want eu-west", got)
	}
	if got := sessionState.Profile.ProviderSettings["device_index"]; got != int64(3) {
		t.Fatalf("session snapshot device_index = %#v, want int64(3)", got)
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
	if challengeEvent.Challenge.CompletionMode != ChallengeCompletionModeManualConfirm {
		t.Fatalf("challenge completion_mode = %q, want %q", challengeEvent.Challenge.CompletionMode, ChallengeCompletionModeManualConfirm)
	}
	if challengeEvent.Challenge.BrowserReturn != nil {
		t.Fatalf("challenge browser_return = %#v, want nil", challengeEvent.Challenge.BrowserReturn)
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

func TestHostStartsResolvesExportsAndMaterializesResolution(t *testing.T) {
	now := time.Date(2026, 4, 10, 12, 0, 0, 0, time.UTC)
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withNow(func() time.Time { return now }),
		WithSessionIDSource(func() string { return "materialized-session" }),
		withRegistry(provider.NewRegistry(
			genericturn.New(),
			fakeAdapter{
				name: "vk",
				resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
					return provider.Resolution{
						Credentials: provider.Credentials{
							Username: "turn-user",
							Password: "turn-pass",
							Address:  "turn.example.test:3478",
							TTL:      45 * time.Minute,
						},
						Metadata: map[string]string{
							"provider":                      "vk",
							"resolution_method":             "staged_http",
							"turn_credential_expires_at":    now.Add(45 * time.Minute).Format(time.RFC3339),
							"turn_credential_expiry_source": "turn_rest_username",
						},
					}, nil
				},
			},
		)),
		withRunnerFactory(func(cfg transport.ClientConfig) transport.Runner {
			return fakeRunner{run: func(ctx context.Context) error {
				if cfg.Hooks.OnReady != nil {
					cfg.Hooks.OnReady()
				}
				<-ctx.Done()
				return nil
			}}
		}),
	)

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	resolved := waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)
	if resolved.Input.Kind != ProviderInputKindLink {
		t.Fatalf("resolution input kind = %q, want %q", resolved.Input.Kind, ProviderInputKindLink)
	}
	if strings.Contains(resolved.Input.LinkRedacted, "test-token") {
		t.Fatalf("resolution input leaked invite token: %q", resolved.Input.LinkRedacted)
	}
	if resolved.Credentials == nil {
		t.Fatal("resolved credentials missing")
	}
	if resolved.Artifact == nil {
		t.Fatal("resolved artifact missing")
	}
	if resolved.Artifact.Family != ArtifactFamilyGenericTURN {
		t.Fatalf("resolved artifact family = %q, want %q", resolved.Artifact.Family, ArtifactFamilyGenericTURN)
	}
	if len(resolved.Artifact.AccessMethods) != 1 || resolved.Artifact.AccessMethods[0] != RuntimeAccessMethodTURNCredentials {
		t.Fatalf("resolved artifact access_methods = %#v, want turn_credentials only", resolved.Artifact.AccessMethods)
	}
	if len(resolved.Artifact.Actions) != 2 {
		t.Fatalf("resolved artifact actions len = %d, want 2", len(resolved.Artifact.Actions))
	}
	if resolved.Artifact.Actions[0].ID != ArtifactActionStartOnThisDevice {
		t.Fatalf("resolved artifact action[0] = %q, want %q", resolved.Artifact.Actions[0].ID, ArtifactActionStartOnThisDevice)
	}
	if resolved.Artifact.Actions[0].ExecutionOwner != ActionExecutionOwnerHost {
		t.Fatalf("resolved artifact action[0].execution_owner = %q, want %q", resolved.Artifact.Actions[0].ExecutionOwner, ActionExecutionOwnerHost)
	}
	if len(resolved.Artifact.Actions[0].ExecutionPlans) != 2 {
		t.Fatalf("resolved artifact action[0].execution_plans len = %d, want 2", len(resolved.Artifact.Actions[0].ExecutionPlans))
	}
	if resolved.Artifact.Actions[0].ExecutionPlans[0].Plan.EngineFamily != RuntimeEngineFamilyCustomPacketOverlay {
		t.Fatalf("resolved artifact action[0].execution_plans[0].engine_family = %q, want %q", resolved.Artifact.Actions[0].ExecutionPlans[0].Plan.EngineFamily, RuntimeEngineFamilyCustomPacketOverlay)
	}
	if resolved.Artifact.Actions[0].ExecutionPlans[1].Plan.EngineFamily != RuntimeEngineFamilyWireGuardNative {
		t.Fatalf("resolved artifact action[0].execution_plans[1].engine_family = %q, want %q", resolved.Artifact.Actions[0].ExecutionPlans[1].Plan.EngineFamily, RuntimeEngineFamilyWireGuardNative)
	}
	if resolved.Artifact.Actions[0].ExecutionPlans[1].SupportState != RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf("resolved artifact action[0].execution_plans[1].support_state = %q, want %q", resolved.Artifact.Actions[0].ExecutionPlans[1].SupportState, RuntimeExecutionPlanSupportStateUnavailable)
	}
	if resolved.Artifact.Actions[1].ID != ArtifactActionExportHandoff {
		t.Fatalf("resolved artifact action[1] = %q, want %q", resolved.Artifact.Actions[1].ID, ArtifactActionExportHandoff)
	}
	if resolved.Artifact.Actions[1].ExecutionOwner != ActionExecutionOwnerHost {
		t.Fatalf("resolved artifact action[1].execution_owner = %q, want %q", resolved.Artifact.Actions[1].ExecutionOwner, ActionExecutionOwnerHost)
	}
	if resolved.Artifact.Summary.GenericTURN == nil {
		t.Fatal("resolved artifact generic_turn summary missing")
	}
	if resolved.Credentials.Address != "turn.example.test:3478" {
		t.Fatalf("resolution address = %q, want turn.example.test:3478", resolved.Credentials.Address)
	}
	if resolved.Credentials.UsernameRedacted != redactedTurnUsername {
		t.Fatalf("resolution username redaction = %q", resolved.Credentials.UsernameRedacted)
	}
	if !resolved.Export.Supported {
		t.Fatal("resolution export supported = false, want true")
	}

	exported, err := host.ExportResolution(resolved.ID)
	if err != nil {
		t.Fatalf("ExportResolution() error = %v", err)
	}
	if exported.Link != "generic-turn://turn-user:turn-pass@turn.example.test:3478" {
		t.Fatalf("exported link = %q", exported.Link)
	}
	if exported.ExpirySource != "turn_rest_username" {
		t.Fatalf("exported expiry_source = %q, want turn_rest_username", exported.ExpirySource)
	}

	sessionState, err := host.MaterializeResolution(context.Background(), resolved.ID, RuntimeDefaults{
		ListenAddr:    reserveUDPAddr(t),
		PeerAddr:      "127.0.0.1:56000",
		Connections:   1,
		TURNServer:    "override.example.test",
		TURNPort:      "5349",
		Mode:          TransportModeAuto,
		UseDTLS:       boolRef(true),
		BindInterface: "127.0.0.1",
		LogLevel:      "debug",
	})
	if err != nil {
		t.Fatalf("MaterializeResolution() error = %v", err)
	}

	ready := waitForSessionState(t, host, sessionState.ID, SessionStateReady)
	if ready.SourceResolutionID != resolved.ID {
		t.Fatalf("session source_resolution_id = %q, want %q", ready.SourceResolutionID, resolved.ID)
	}
	if strings.Contains(ready.Profile.Link, "generic-turn://turn-user:turn-pass@") {
		t.Fatalf("session profile leaked handoff secret: %q", ready.Profile.Link)
	}
	if ready.Profile.TURNServer != "override.example.test" {
		t.Fatalf("session turn_server = %q, want override.example.test", ready.Profile.TURNServer)
	}
	if ready.Profile.TURNPort != "5349" {
		t.Fatalf("session turn_port = %q, want 5349", ready.Profile.TURNPort)
	}
	if ready.Profile.BindInterface != "127.0.0.1" {
		t.Fatalf("session bind_interface = %q, want 127.0.0.1", ready.Profile.BindInterface)
	}
	if ready.Profile.LogLevel != "debug" {
		t.Fatalf("session log_level = %q, want debug", ready.Profile.LogLevel)
	}

	diagnostics, err := host.ExportDiagnostics(ready.ID)
	if err != nil {
		t.Fatalf("ExportDiagnostics() error = %v", err)
	}
	if diagnostics.Session.SourceResolutionID != resolved.ID {
		t.Fatalf("diagnostics source_resolution_id = %q, want %q", diagnostics.Session.SourceResolutionID, resolved.ID)
	}
	if strings.Contains(diagnostics.Session.Profile.Link, "generic-turn://turn-user:turn-pass@") {
		t.Fatalf("diagnostics leaked handoff secret: %q", diagnostics.Session.Profile.Link)
	}
	if diagnostics.Session.Profile.TURNServer != "override.example.test" {
		t.Fatalf("diagnostics turn_server = %q, want override.example.test", diagnostics.Session.Profile.TURNServer)
	}
	if diagnostics.Session.Profile.TURNPort != "5349" {
		t.Fatalf("diagnostics turn_port = %q, want 5349", diagnostics.Session.Profile.TURNPort)
	}

	if _, err := host.StopSession(ready.ID); err != nil {
		t.Fatalf("StopSession() error = %v", err)
	}
	if _, err := host.WaitSession(context.Background(), ready.ID); err != nil {
		t.Fatalf("WaitSession() error = %v", err)
	}
}

func TestHostResolutionChallengeContinuation(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			descriptor: provider.ProviderDescriptor{
				ID:             "vk",
				DisplayName:    "VK Calls",
				InputKind:      provider.ProviderInputKindLink,
				AuthPosture:    provider.ProviderAuthPostureGuestOrAccount,
				BrowserPolicy:  provider.ProviderBrowserPolicyExternalRequired,
				ChallengeModes: []provider.ProviderChallengeMode{provider.ProviderChallengeModeBrowser},
			},
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
						TTL:      time.Minute,
					},
					Metadata: map[string]string{
						"provider":          "vk",
						"resolution_method": "browser_continuation",
					},
				}, nil
			},
		})),
		withContinuationStarter(func(ctx context.Context, challenge provider.InteractiveChallenge) (browserContinuation, error) {
			return fakeContinuation{result: &provider.BrowserContinuation{}}, nil
		}),
	)

	events, cancel := host.Subscribe(16)
	defer cancel()

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	challengeEvent := waitForEvent(t, events, EventChallengeRequired)
	if challengeEvent.Challenge == nil {
		t.Fatal("challenge event missing payload")
	}
	if challengeEvent.Challenge.ResolutionID != resolutionState.ID {
		t.Fatalf("challenge resolution_id = %q, want %q", challengeEvent.Challenge.ResolutionID, resolutionState.ID)
	}
	if challengeEvent.Challenge.CompletionMode != ChallengeCompletionModeManualConfirm {
		t.Fatalf("challenge completion_mode = %q, want %q", challengeEvent.Challenge.CompletionMode, ChallengeCompletionModeManualConfirm)
	}
	if challengeEvent.Challenge.BrowserReturn != nil {
		t.Fatalf("challenge browser_return = %#v, want nil", challengeEvent.Challenge.BrowserReturn)
	}

	challenge, err := host.ContinueChallenge(challengeEvent.Challenge.ID)
	if err != nil {
		t.Fatalf("ContinueChallenge() error = %v", err)
	}
	if challenge.Status != ChallengeStatusContinuing {
		t.Fatalf("challenge status = %q, want continuing", challenge.Status)
	}

	waitForEvent(t, events, EventChallengeUpdated)
	resolvedEvent := waitForEvent(t, events, EventResolutionResolved)
	if resolvedEvent.Artifact == nil || resolvedEvent.Artifact.Family != ArtifactFamilyGenericTURN {
		t.Fatalf("resolved event artifact = %#v, want generic_turn artifact", resolvedEvent.Artifact)
	}
	resolved := waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)
	if !resolved.Input.InteractiveProvider {
		t.Fatalf("resolution input interactive_provider = false, want true")
	}
}

func TestHostResolutionChallengeExposesAppReturnMetadata(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			descriptor: provider.ProviderDescriptor{
				ID:             "vk",
				DisplayName:    "VK Calls",
				InputKind:      provider.ProviderInputKindLink,
				AuthPosture:    provider.ProviderAuthPostureGuestOrAccount,
				BrowserPolicy:  provider.ProviderBrowserPolicyExternalRequired,
				ChallengeModes: []provider.ProviderChallengeMode{provider.ProviderChallengeModeBrowser},
			},
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				handler := provider.BrowserContinuationHandlerFromContext(ctx)
				if handler == nil {
					return provider.Resolution{}, io.ErrUnexpectedEOF
				}
				if _, err := handler.Continue(ctx, fakeChallenge{
					provider: "vk",
					stage:    "provider_resolve",
					kind:     "browser",
					prompt:   "return after browser",
					openURL:  "https://example.test/challenge",
					metadata: provider.InteractiveChallengeMetadata{
						CompletionMode: provider.ChallengeCompletionModeAppReturnCallback,
						BrowserReturn: &provider.BrowserReturnMetadata{
							SignalKinds: []provider.BrowserReturnSignalKind{
								provider.BrowserReturnSignalKindForegroundResume,
								provider.BrowserReturnSignalKindForegroundResume,
								provider.BrowserReturnSignalKindAppLink,
							},
							AllowAutoContinue: true,
							ExpectedReturnURI: "  https://app.example.test/mobile-return  ",
						},
					},
				}); err != nil {
					return provider.Resolution{}, err
				}
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
				}, nil
			},
		})),
		withContinuationStarter(func(ctx context.Context, challenge provider.InteractiveChallenge) (browserContinuation, error) {
			return fakeContinuation{result: &provider.BrowserContinuation{}}, nil
		}),
	)

	events, cancel := host.Subscribe(16)
	defer cancel()

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	challengeEvent := waitForEvent(t, events, EventChallengeRequired)
	if challengeEvent.Challenge == nil {
		t.Fatal("challenge event missing payload")
	}
	if challengeEvent.Challenge.CompletionMode != ChallengeCompletionModeAppReturnCallback {
		t.Fatalf("challenge completion_mode = %q, want %q", challengeEvent.Challenge.CompletionMode, ChallengeCompletionModeAppReturnCallback)
	}
	if challengeEvent.Challenge.BrowserReturn == nil {
		t.Fatal("challenge browser_return = nil, want metadata")
	}
	if !challengeEvent.Challenge.BrowserReturn.AllowAutoContinue {
		t.Fatal("challenge browser_return.allow_auto_continue = false, want true")
	}
	if got := challengeEvent.Challenge.BrowserReturn.ExpectedReturnURI; got != "https://app.example.test/mobile-return" {
		t.Fatalf("challenge browser_return.expected_return_uri = %q, want https://app.example.test/mobile-return", got)
	}
	if got := challengeEvent.Challenge.BrowserReturn.SignalKinds; len(got) != 2 ||
		got[0] != BrowserReturnSignalKindForegroundResume ||
		got[1] != BrowserReturnSignalKindAppLink {
		t.Fatalf("challenge browser_return.signal_kinds = %#v, want foreground_resume,app_link", got)
	}

	if _, err := host.ContinueChallenge(challengeEvent.Challenge.ID); err != nil {
		t.Fatalf("ContinueChallenge() error = %v", err)
	}
	waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)
}

func TestHostResolutionChallengeOwnedBrowserUsesSubmittedContinuation(t *testing.T) {
	var (
		seenCookieValue string
		startedExternal bool
	)
	stageServer := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/captcha/continue" {
			http.NotFound(w, r)
			return
		}
		if err := r.ParseForm(); err != nil {
			t.Fatalf("ParseForm() error = %v", err)
		}
		cookie, err := r.Cookie("session")
		if err != nil {
			t.Fatalf("Cookie(session) error = %v", err)
		}
		seenCookieValue = cookie.Value
		if got := r.PostForm.Get("code"); got != "captcha-ok" {
			t.Fatalf("POST form code = %q, want captcha-ok", got)
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok","ticket":"captcha-ticket"}`))
	}))
	defer stageServer.Close()

	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			descriptor: provider.ProviderDescriptor{
				ID:             "vk",
				DisplayName:    "VK Calls",
				InputKind:      provider.ProviderInputKindLink,
				AuthPosture:    provider.ProviderAuthPostureGuestOrAccount,
				BrowserPolicy:  provider.ProviderBrowserPolicyExternalRequired,
				ChallengeModes: []provider.ProviderChallengeMode{provider.ProviderChallengeModeBrowser},
			},
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				handler := provider.BrowserContinuationHandlerFromContext(ctx)
				if handler == nil {
					return provider.Resolution{}, io.ErrUnexpectedEOF
				}
				continuation, err := handler.Continue(ctx, fakeOwnedBrowserChallenge{
					fakeChallenge: fakeChallenge{
						provider: "vk",
						stage:    "provider_resolve",
						kind:     "captcha",
						prompt:   "complete captcha",
						openURL:  "https://example.test/challenge",
						metadata: provider.InteractiveChallengeMetadata{
							CompletionMode: provider.ChallengeCompletionModeOwnedBrowserObserved,
						},
					},
					cookieURLs: []string{
						stageServer.URL,
					},
					stageRequests: []provider.BrowserStageRequest{
						{
							Stage:  "captcha_submit",
							Method: http.MethodPost,
							URL:    stageServer.URL + "/captcha/continue",
							Form: map[string]string{
								"code": "captcha-ok",
							},
						},
					},
				})
				if err != nil {
					return provider.Resolution{}, err
				}
				if len(continuation.Cookies) != 1 {
					t.Fatalf("continuation cookies len = %d, want 1", len(continuation.Cookies))
				}
				if continuation.Cookies[0].Value != "owned-session" {
					t.Fatalf("continuation cookie value = %q, want owned-session", continuation.Cookies[0].Value)
				}
				stageResult, ok := continuation.StageResult("captcha_submit")
				if !ok {
					t.Fatal("continuation missing captcha_submit stage result")
				}
				if got := stageResult.Body["ticket"]; got != "captcha-ticket" {
					t.Fatalf("stage result ticket = %#v, want captcha-ticket", got)
				}
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
				}, nil
			},
		})),
		withContinuationStarter(func(ctx context.Context, challenge provider.InteractiveChallenge) (browserContinuation, error) {
			startedExternal = true
			return fakeContinuation{result: &provider.BrowserContinuation{}}, nil
		}),
	)

	events, cancel := host.Subscribe(16)
	defer cancel()

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	challengeEvent := waitForEvent(t, events, EventChallengeRequired)
	if challengeEvent.Challenge == nil {
		t.Fatal("challenge event missing payload")
	}
	if challengeEvent.Challenge.CompletionMode != ChallengeCompletionModeOwnedBrowserObserved {
		t.Fatalf("challenge completion_mode = %q, want %q", challengeEvent.Challenge.CompletionMode, ChallengeCompletionModeOwnedBrowserObserved)
	}
	if challengeEvent.Challenge.OwnedBrowser == nil {
		t.Fatal("challenge owned_browser = nil, want metadata")
	}
	if got := challengeEvent.Challenge.OwnedBrowser.CookieURLs; len(got) != 1 || got[0] != stageServer.URL {
		t.Fatalf("challenge owned_browser.cookie_urls = %#v, want %q", got, stageServer.URL)
	}

	challenge, err := host.ContinueChallengeWithBrowserContinuation(
		challengeEvent.Challenge.ID,
		&ChallengeContinuation{
			Cookies: []BrowserCookie{
				{
					Name:   "session",
					Value:  "owned-session",
					Domain: "127.0.0.1",
					Path:   "/",
				},
			},
		},
	)
	if err != nil {
		t.Fatalf("ContinueChallengeWithBrowserContinuation() error = %v", err)
	}
	if challenge.Status != ChallengeStatusContinuing {
		t.Fatalf("challenge status = %q, want continuing", challenge.Status)
	}

	waitForEvent(t, events, EventChallengeUpdated)
	waitForEvent(t, events, EventResolutionResolved)
	waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)

	if startedExternal {
		t.Fatal("startContinuation() called for owned browser challenge, want in-app continuation path")
	}
	if seenCookieValue != "owned-session" {
		t.Fatalf("stage request cookie value = %q, want owned-session", seenCookieValue)
	}
}

func TestHostResolutionChallengeOwnedBrowserFailsClosedWithoutCookieURLs(t *testing.T) {
	var startedExternal bool

	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			descriptor: provider.ProviderDescriptor{
				ID:             "vk",
				DisplayName:    "VK Calls",
				InputKind:      provider.ProviderInputKindLink,
				AuthPosture:    provider.ProviderAuthPostureGuestOrAccount,
				BrowserPolicy:  provider.ProviderBrowserPolicyExternalRequired,
				ChallengeModes: []provider.ProviderChallengeMode{provider.ProviderChallengeModeBrowser},
			},
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				handler := provider.BrowserContinuationHandlerFromContext(ctx)
				if handler == nil {
					return provider.Resolution{}, io.ErrUnexpectedEOF
				}
				if _, err := handler.Continue(ctx, fakeOwnedBrowserChallenge{
					fakeChallenge: fakeChallenge{
						provider: "vk",
						stage:    "provider_resolve",
						kind:     "browser",
						prompt:   "return after browser",
						openURL:  "https://example.test/challenge",
						metadata: provider.InteractiveChallengeMetadata{
							CompletionMode: provider.ChallengeCompletionModeOwnedBrowserObserved,
						},
					},
				}); err != nil {
					return provider.Resolution{}, err
				}
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
				}, nil
			},
		})),
		withContinuationStarter(func(ctx context.Context, challenge provider.InteractiveChallenge) (browserContinuation, error) {
			startedExternal = true
			return fakeContinuation{result: &provider.BrowserContinuation{}}, nil
		}),
	)

	events, cancel := host.Subscribe(16)
	defer cancel()

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	challengeEvent := waitForEvent(t, events, EventChallengeRequired)
	if challengeEvent.Challenge == nil {
		t.Fatal("challenge event missing payload")
	}
	if challengeEvent.Challenge.CompletionMode != ChallengeCompletionModeManualConfirm {
		t.Fatalf("challenge completion_mode = %q, want %q", challengeEvent.Challenge.CompletionMode, ChallengeCompletionModeManualConfirm)
	}
	if challengeEvent.Challenge.OwnedBrowser != nil {
		t.Fatalf("challenge owned_browser = %#v, want nil", challengeEvent.Challenge.OwnedBrowser)
	}

	if _, err := host.ContinueChallenge(challengeEvent.Challenge.ID); err != nil {
		t.Fatalf("ContinueChallenge() error = %v", err)
	}
	waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)

	if !startedExternal {
		t.Fatal("startContinuation() not called, want fail-closed external browser path")
	}
}

func TestResolutionArtifactFromNonTURNFamilyKeepsSummaryRedacted(t *testing.T) {
	descriptor := ProviderDescriptor{
		ID:               "roomy",
		DisplayName:      "Roomy",
		InputKind:        ProviderInputKindLink,
		ArtifactFamilies: []ArtifactFamily{ArtifactFamilyConferenceRoom},
		CapabilityHints: ProviderCapabilityHints{
			PotentialActions: []ArtifactAction{ArtifactActionOpenRoom},
			RedactionPolicy: ArtifactRedactionPolicy{
				OrdinaryReads:  ArtifactRedactionModeSummaryOnly,
				Events:         ArtifactRedactionModeSummaryOnly,
				Diagnostics:    ArtifactRedactionModeSummaryOnly,
				PersistedState: ArtifactRedactionModeSummaryOnly,
			},
		},
	}
	resolved := provider.Resolution{
		Artifact: &provider.ProbeArtifact{
			Provider:         "roomy",
			ResolutionMethod: "room_join",
			Input: provider.ProbeArtifactInput{
				LinkRedacted: "https://room.example.test/join/<redacted:room-token>",
			},
			Stages: []provider.ProbeArtifactStage{
				{
					Name:       "room_join",
					EndpointID: "room_join",
					Request: provider.ProbeArtifactStageRequest{
						Method:         "POST",
						FormKeys:       []string{"room_token", "chat_token"},
						RedactedFields: []string{"room_token", "chat_token"},
					},
					Response: provider.ProbeArtifactStageResponse{
						StatusCode: 200,
						Body: map[string]any{
							"room_token": "secret-room-token",
							"chat_token": "secret-chat-token",
						},
					},
					Outcome: provider.ProbeArtifactStageOutcome{
						Kind: "resolution",
						Extracted: map[string]any{
							"room_token": "secret-room-token",
							"chat_token": "secret-chat-token",
						},
					},
				},
			},
			Outcome: provider.ProbeArtifactOutcome{
				ResultKind: "conference_room",
				ConferenceRoom: &provider.ProbeArtifactConferenceRoom{
					RoomURL: "https://room.example.test/rooms/team-sync",
				},
			},
		},
	}

	artifact := resolutionArtifactFromResolution(
		descriptor,
		resolved,
		ResolutionExportStatus{Supported: false},
		nil,
	)
	if artifact == nil {
		t.Fatal("resolution artifact = nil, want conference_room artifact")
	}
	if artifact.Family != ArtifactFamilyConferenceRoom {
		t.Fatalf("resolution artifact family = %q, want %q", artifact.Family, ArtifactFamilyConferenceRoom)
	}
	if len(artifact.AccessMethods) != 0 {
		t.Fatalf("resolution artifact access_methods = %#v, want empty", artifact.AccessMethods)
	}
	if len(artifact.Actions) != 1 || artifact.Actions[0].ID != ArtifactActionOpenRoom {
		t.Fatalf("resolution artifact actions = %#v, want open_room only", artifact.Actions)
	}
	if artifact.Actions[0].ExecutionOwner != ActionExecutionOwnerShellExternal {
		t.Fatalf("resolution artifact action execution_owner = %q, want %q", artifact.Actions[0].ExecutionOwner, ActionExecutionOwnerShellExternal)
	}
	if artifact.Summary.GenericTURN != nil {
		t.Fatalf("resolution artifact generic_turn summary = %#v, want nil", artifact.Summary.GenericTURN)
	}
	if artifact.Summary.ConferenceRoom == nil {
		t.Fatal("resolution artifact conference_room summary = nil, want room summary")
	}
	if artifact.Summary.ConferenceRoom.RoomURL != "https://room.example.test/rooms/team-sync" {
		t.Fatalf("resolution artifact conference_room room_url = %q, want team-sync room", artifact.Summary.ConferenceRoom.RoomURL)
	}

	artifactJSON, err := json.Marshal(artifact)
	if err != nil {
		t.Fatalf("json.Marshal(artifact) error = %v", err)
	}
	if strings.Contains(string(artifactJSON), "secret-room-token") || strings.Contains(string(artifactJSON), "secret-chat-token") {
		t.Fatalf("resolution artifact leaked non-TURN secrets: %s", artifactJSON)
	}

	eventJSON, err := json.Marshal(
		resolutionSnapshotEvent(
			Resolution{
				ID:        "resolution-1",
				State:     ResolutionStateResolved,
				UpdatedAt: time.Date(2026, 4, 11, 12, 0, 0, 0, time.UTC),
				Artifact:  artifact,
			},
			EventResolutionResolved,
			"",
		),
	)
	if err != nil {
		t.Fatalf("json.Marshal(event) error = %v", err)
	}
	if strings.Contains(string(eventJSON), "secret-room-token") || strings.Contains(string(eventJSON), "secret-chat-token") {
		t.Fatalf("resolution event leaked non-TURN secrets: %s", eventJSON)
	}
}

func TestResolutionArtifactFromCameraStreamFamilyExposesTypedExternalTargets(t *testing.T) {
	descriptor := ProviderDescriptor{
		ID:               "cams",
		DisplayName:      "Camera portal",
		InputKind:        ProviderInputKindLink,
		ArtifactFamilies: []ArtifactFamily{ArtifactFamilyCameraStream},
		CapabilityHints: ProviderCapabilityHints{
			PotentialActions: []ArtifactAction{
				ArtifactActionOpenCamera,
				ArtifactActionOpenArchive,
			},
			RedactionPolicy: ArtifactRedactionPolicy{
				OrdinaryReads:  ArtifactRedactionModeSummaryOnly,
				Events:         ArtifactRedactionModeSummaryOnly,
				Diagnostics:    ArtifactRedactionModeSummaryOnly,
				PersistedState: ArtifactRedactionModeSummaryOnly,
			},
		},
	}
	resolved := provider.Resolution{
		Artifact: &provider.ProbeArtifact{
			Provider:         "cams",
			ResolutionMethod: "camera_open",
			Input: provider.ProbeArtifactInput{
				LinkRedacted: "https://camera.example.test/devices/<redacted:device-id>",
			},
			Outcome: provider.ProbeArtifactOutcome{
				ResultKind: "camera_stream",
				CameraStream: &provider.ProbeArtifactCameraStream{
					CameraURL:  "https://camera.example.test/devices/42/live",
					ArchiveURL: "https://camera.example.test/devices/42/archive",
				},
			},
		},
	}

	artifact := resolutionArtifactFromResolution(
		descriptor,
		resolved,
		ResolutionExportStatus{Supported: false},
		nil,
	)
	if artifact == nil {
		t.Fatal("resolution artifact = nil, want camera_stream artifact")
	}
	if artifact.Family != ArtifactFamilyCameraStream {
		t.Fatalf("resolution artifact family = %q, want %q", artifact.Family, ArtifactFamilyCameraStream)
	}
	if len(artifact.Actions) != 2 {
		t.Fatalf("resolution artifact actions len = %d, want 2", len(artifact.Actions))
	}
	if artifact.Actions[0].ID != ArtifactActionOpenCamera || artifact.Actions[1].ID != ArtifactActionOpenArchive {
		t.Fatalf("resolution artifact actions = %#v, want open_camera/open_archive", artifact.Actions)
	}
	if artifact.Summary.CameraStream == nil {
		t.Fatal("resolution artifact camera_stream summary = nil, want typed summary")
	}
	if artifact.Summary.CameraStream.CameraURL != "https://camera.example.test/devices/42/live" {
		t.Fatalf("resolution artifact camera_url = %q, want live target", artifact.Summary.CameraStream.CameraURL)
	}
	if artifact.Summary.CameraStream.ArchiveURL != "https://camera.example.test/devices/42/archive" {
		t.Fatalf("resolution artifact archive_url = %q, want archive target", artifact.Summary.CameraStream.ArchiveURL)
	}
}

func TestHostStartResolutionResolvesConferenceRoomArtifactWithoutTURNCredentials(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "roomy",
			descriptor: provider.ProviderDescriptor{
				ID:               "roomy",
				DisplayName:      "Roomy",
				InputKind:        provider.ProviderInputKindLink,
				ArtifactFamilies: []provider.ArtifactFamily{provider.ArtifactFamilyConferenceRoom},
				CapabilityHints: provider.ProviderCapabilityHints{
					PotentialActions: []provider.ArtifactAction{provider.ArtifactActionOpenRoom},
					RedactionPolicy:  provider.SummaryOnlyArtifactRedactionPolicy(),
				},
			},
			resolve: func(context.Context, string) (provider.Resolution, error) {
				return provider.Resolution{
					Metadata: map[string]string{
						"provider":          "roomy",
						"resolution_method": "room_join",
					},
					Artifact: &provider.ProbeArtifact{
						Provider:         "roomy",
						ResolutionMethod: "room_join",
						Input: provider.ProbeArtifactInput{
							LinkRedacted: "https://room.example.test/join/<redacted:room-token>",
						},
						Outcome: provider.ProbeArtifactOutcome{
							ResultKind: "conference_room",
							ConferenceRoom: &provider.ProbeArtifactConferenceRoom{
								RoomURL: "https://room.example.test/rooms/team-sync",
							},
						},
					},
				}, nil
			},
		})),
	)

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "roomy",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://room.example.test/join/test-room-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	resolved := waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)
	if resolved.Credentials != nil {
		t.Fatalf("resolved credentials = %#v, want nil for conference_room artifact", resolved.Credentials)
	}
	if resolved.Export.Supported {
		t.Fatal("resolved export supported = true, want false for conference_room artifact")
	}
	if resolved.Artifact == nil {
		t.Fatal("resolved artifact = nil, want conference_room artifact")
	}
	if resolved.Artifact.Family != ArtifactFamilyConferenceRoom {
		t.Fatalf("resolved artifact family = %q, want %q", resolved.Artifact.Family, ArtifactFamilyConferenceRoom)
	}
	if resolved.Artifact.Summary.ConferenceRoom == nil {
		t.Fatal("resolved artifact conference_room summary = nil, want room target")
	}
	if resolved.Artifact.Summary.ConferenceRoom.RoomURL != "https://room.example.test/rooms/team-sync" {
		t.Fatalf("resolved room_url = %q, want room target", resolved.Artifact.Summary.ConferenceRoom.RoomURL)
	}
	if len(resolved.Artifact.Actions) != 1 || resolved.Artifact.Actions[0].ID != ArtifactActionOpenRoom {
		t.Fatalf("resolved artifact actions = %#v, want open_room only", resolved.Artifact.Actions)
	}
}

func TestHostResolutionFailureRedactsArtifactErrorMessage(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "roomy",
			descriptor: provider.ProviderDescriptor{
				ID:               "roomy",
				DisplayName:      "Roomy",
				InputKind:        provider.ProviderInputKindLink,
				ArtifactFamilies: []provider.ArtifactFamily{provider.ArtifactFamilyConferenceRoom},
				CapabilityHints: provider.ProviderCapabilityHints{
					PotentialActions: []provider.ArtifactAction{provider.ArtifactActionOpenRoom},
					RedactionPolicy:  provider.SummaryOnlyArtifactRedactionPolicy(),
				},
			},
			resolve: func(context.Context, string) (provider.Resolution, error) {
				return provider.Resolution{}, &provider.ArtifactError{
					Err: errors.New("room token leaked: secret-room-token"),
					ProbeArtifact: &provider.ProbeArtifact{
						Provider: "roomy",
						Input: provider.ProbeArtifactInput{
							LinkRedacted: "https://room.example.test/join/<redacted:room-token>",
						},
						Outcome: provider.ProbeArtifactOutcome{
							ResultKind: "provider_error",
							ProviderError: &provider.ProbeArtifactProviderError{
								Stage: "room_join",
								Code:  "invalid_room_token",
							},
						},
					},
				}
			},
		})),
	)

	events, cancel := host.Subscribe(16)
	defer cancel()

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "roomy",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://room.example.test/join/secret-room-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	failed := waitForResolutionState(t, host, resolutionState.ID, ResolutionStateFailed)
	if failed.Failure == nil {
		t.Fatal("resolution failure = nil, want redacted failure info")
	}
	if strings.Contains(failed.Failure.Message, "secret-room-token") {
		t.Fatalf("resolution failure leaked raw secret: %q", failed.Failure.Message)
	}
	if failed.Failure.Message != "provider resolution failed at room_join [invalid_room_token]" {
		t.Fatalf("resolution failure message = %q", failed.Failure.Message)
	}
	if failed.Failure.Stage != "room_join" {
		t.Fatalf("resolution failure stage = %q, want room_join", failed.Failure.Stage)
	}
	if strings.Contains(failed.Input.LinkRedacted, "secret-room-token") {
		t.Fatalf("resolution input leaked room token: %q", failed.Input.LinkRedacted)
	}

	failedEvent := waitForEvent(t, events, EventResolutionFailed)
	if strings.Contains(failedEvent.Message, "secret-room-token") {
		t.Fatalf("resolution failure event leaked raw secret: %q", failedEvent.Message)
	}
	if failedEvent.Message != failed.Failure.Message {
		t.Fatalf("resolution failure event message = %q, want %q", failedEvent.Message, failed.Failure.Message)
	}
}

func TestHostRequiresTypedInputEnvelope(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "future",
			descriptor: provider.ProviderDescriptor{
				ID:          "future",
				DisplayName: "Future",
				InputKind:   provider.ProviderInputKind("opaque_token"),
			},
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				t.Fatal("Resolve() should not be called when legacy bridge is rejected")
				return provider.Resolution{}, nil
			},
		})),
	)

	if _, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "future",
	}); err == nil {
		t.Fatal("StartResolution() error = nil, want missing typed input")
	} else if !strings.Contains(err.Error(), "input is required") {
		t.Fatalf("StartResolution() error = %v, want missing typed input", err)
	}
}

func TestHostResolutionExportFailsWithoutAuthoritativeExpiry(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
					},
					Metadata: map[string]string{
						"provider":          "vk",
						"resolution_method": "staged_http",
					},
				}, nil
			},
		})),
	)

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}
	waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)

	current, err := host.Resolution(resolutionState.ID)
	if err != nil {
		t.Fatalf("Resolution() error = %v", err)
	}
	if current.Artifact == nil {
		t.Fatal("resolution artifact missing")
	}
	if len(current.Artifact.Actions) != 1 || current.Artifact.Actions[0].ID != ArtifactActionStartOnThisDevice {
		t.Fatalf("resolution artifact actions = %#v, want start_on_this_device only", current.Artifact.Actions)
	}
	if current.Artifact.Actions[0].ExecutionOwner != ActionExecutionOwnerHost {
		t.Fatalf("resolution artifact action execution_owner = %q, want %q", current.Artifact.Actions[0].ExecutionOwner, ActionExecutionOwnerHost)
	}
	if len(current.Artifact.Actions[0].ExecutionPlans) != 2 {
		t.Fatalf("resolution artifact execution_plans = %#v, want current and packaged plans", current.Artifact.Actions[0].ExecutionPlans)
	}

	_, err = host.ExportResolution(resolutionState.ID)
	if !errors.Is(err, errResolutionExportUnavailable) {
		t.Fatalf("ExportResolution() error = %v, want export unavailable", err)
	}
	var actionErr *ResolutionActionError
	if !errors.As(err, &actionErr) {
		t.Fatalf("ExportResolution() error = %T, want ResolutionActionError", err)
	}
	if actionErr.Action != ArtifactActionExportHandoff {
		t.Fatalf("ExportResolution() action = %q, want %q", actionErr.Action, ArtifactActionExportHandoff)
	}
}

func TestHostMaterializeResolutionFailsWhenArtifactDoesNotAdvertiseStartAction(t *testing.T) {
	now := time.Date(2026, 4, 10, 12, 0, 0, 0, time.UTC)
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withNow(func() time.Time { return now }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			descriptor: provider.ProviderDescriptor{
				ID:               "vk",
				DisplayName:      "VK Calls",
				InputKind:        provider.ProviderInputKindLink,
				BrowserPolicy:    provider.ProviderBrowserPolicyExternalRequired,
				ArtifactFamilies: []provider.ArtifactFamily{provider.ArtifactFamilyGenericTURN},
				CapabilityHints: provider.ProviderCapabilityHints{
					PotentialActions: []provider.ArtifactAction{provider.ArtifactActionExportHandoff},
					RedactionPolicy:  provider.SummaryOnlyArtifactRedactionPolicy(),
				},
			},
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
						TTL:      time.Hour,
					},
					Metadata: map[string]string{
						"provider":                      "vk",
						"resolution_method":             "staged_http",
						"turn_credential_expires_at":    now.Add(time.Hour).Format(time.RFC3339),
						"turn_credential_expiry_source": "turn_rest_username",
					},
				}, nil
			},
		})),
	)

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	resolved := waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)
	if resolved.Artifact == nil {
		t.Fatal("resolved artifact missing")
	}
	if len(resolved.Artifact.Actions) != 1 || resolved.Artifact.Actions[0].ID != ArtifactActionExportHandoff {
		t.Fatalf("resolution artifact actions = %#v, want export_handoff only", resolved.Artifact.Actions)
	}

	_, err = host.MaterializeResolution(context.Background(), resolved.ID, RuntimeDefaults{
		ListenAddr:  reserveUDPAddr(t),
		PeerAddr:    "127.0.0.1:56000",
		Connections: 1,
		Mode:        TransportModeAuto,
		UseDTLS:     boolRef(true),
	})
	if !errors.Is(err, errResolutionNotTransportReady) {
		t.Fatalf("MaterializeResolution() error = %v, want not transport-ready", err)
	}
	var actionErr *ResolutionActionError
	if !errors.As(err, &actionErr) {
		t.Fatalf("MaterializeResolution() error = %T, want ResolutionActionError", err)
	}
	if actionErr.Action != ArtifactActionStartOnThisDevice {
		t.Fatalf("MaterializeResolution() action = %q, want %q", actionErr.Action, ArtifactActionStartOnThisDevice)
	}
	if actionErr.Plan != nil {
		t.Fatalf("MaterializeResolution() requested plan = %#v, want nil default selection", actionErr.Plan)
	}
}

func TestHostResolutionExpiresAndFailsClosed(t *testing.T) {
	now := time.Date(2026, 4, 10, 12, 0, 0, 0, time.UTC)
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withNow(func() time.Time { return now }),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
						TTL:      time.Minute,
					},
					Metadata: map[string]string{
						"provider":          "vk",
						"resolution_method": "staged_http",
					},
				}, nil
			},
		})),
	)

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}
	waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)

	now = now.Add(2 * time.Minute)
	expired, err := host.Resolution(resolutionState.ID)
	if err != nil {
		t.Fatalf("Resolution() error = %v", err)
	}
	if expired.State != ResolutionStateExpired {
		t.Fatalf("resolution state = %q, want expired", expired.State)
	}
	if expired.Artifact == nil {
		t.Fatal("expired resolution artifact missing")
	}
	if len(expired.Artifact.Actions) != 0 {
		t.Fatalf("expired resolution artifact actions = %#v, want none", expired.Artifact.Actions)
	}
	if _, err := host.ExportResolution(resolutionState.ID); !errors.Is(err, errResolutionExpired) {
		t.Fatalf("ExportResolution() error = %v, want expired", err)
	}
	if _, err := host.MaterializeResolution(context.Background(), resolutionState.ID, RuntimeDefaults{
		ListenAddr:  reserveUDPAddr(t),
		PeerAddr:    "127.0.0.1:56000",
		Connections: 1,
		Mode:        TransportModeAuto,
		UseDTLS:     boolRef(true),
	}); !errors.Is(err, errResolutionExpired) {
		t.Fatalf("MaterializeResolution() error = %v, want expired", err)
	}
}

func TestHostCancelResolutionStaysCancelledIfProviderFinishesLate(t *testing.T) {
	release := make(chan struct{})
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "vk",
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				<-release
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
						TTL:      time.Minute,
					},
					Metadata: map[string]string{
						"provider":                      "vk",
						"resolution_method":             "staged_http",
						"turn_credential_expires_at":    time.Now().UTC().Add(time.Minute).Format(time.RFC3339),
						"turn_credential_expiry_source": "turn_rest_username",
					},
				}, nil
			},
		})),
	)

	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}

	cancelled, err := host.CancelResolution(resolutionState.ID)
	if err != nil {
		t.Fatalf("CancelResolution() error = %v", err)
	}
	if cancelled.State != ResolutionStateCancelled {
		t.Fatalf("cancelled state = %q, want cancelled", cancelled.State)
	}

	close(release)

	deadline := time.After(3 * time.Second)
	for {
		current, err := host.Resolution(resolutionState.ID)
		if err != nil {
			t.Fatalf("Resolution() error = %v", err)
		}
		if current.State == ResolutionStateCancelled {
			break
		}
		select {
		case <-deadline:
			t.Fatalf("resolution state = %q, want cancelled", current.State)
		case <-time.After(10 * time.Millisecond):
		}
	}

	if _, err := host.ExportResolution(resolutionState.ID); !errors.Is(err, errResolutionNotTransportReady) {
		t.Fatalf("ExportResolution() error = %v, want not transport-ready", err)
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

func waitForResolutionState(t *testing.T, host *Host, resolutionID string, want ResolutionState) Resolution {
	t.Helper()
	deadline := time.After(3 * time.Second)
	for {
		resolutionState, err := host.Resolution(resolutionID)
		if err != nil {
			t.Fatalf("Resolution() error = %v", err)
		}
		if resolutionState.State == want {
			return resolutionState
		}
		select {
		case <-deadline:
			t.Fatalf("timed out waiting for resolution %s state %s; got %s", resolutionID, want, resolutionState.State)
		case <-time.After(10 * time.Millisecond):
		}
	}
}

func providerSettingsTestDescriptor(providerID string) provider.ProviderDescriptor {
	minLength := 4
	maxLength := 12
	minimum := 1.0
	maximum := 4.0

	return provider.ProviderDescriptor{
		ID:            providerID,
		DisplayName:   "Schema provider",
		InputKind:     provider.ProviderInputKindLink,
		AuthPosture:   provider.ProviderAuthPostureAccount,
		BrowserPolicy: provider.ProviderBrowserPolicyNotRequired,
		SettingsSchema: &provider.ProviderSettingsSchema{
			Type:                 "object",
			AdditionalProperties: false,
			Required:             []string{"region", "device_pin"},
			Order:                []string{"region", "device_index", "device_pin"},
			Properties: map[string]provider.ProviderSettingProperty{
				"region": {
					Type:        provider.ProviderSettingTypeString,
					Title:       "Region",
					Enum:        []any{"ru-central", "eu-west"},
					Control:     provider.ProviderSettingControlSelect,
					Persistence: provider.ProviderSettingPersistenceProfile,
				},
				"device_index": {
					Type:        provider.ProviderSettingTypeInteger,
					Title:       "Device index",
					Minimum:     &minimum,
					Maximum:     &maximum,
					Control:     provider.ProviderSettingControlText,
					Persistence: provider.ProviderSettingPersistenceProfile,
				},
				"device_pin": {
					Type:        provider.ProviderSettingTypeString,
					Title:       "Device PIN",
					WriteOnly:   true,
					MinLength:   &minLength,
					MaxLength:   &maxLength,
					Control:     provider.ProviderSettingControlPassword,
					Persistence: provider.ProviderSettingPersistenceEphemeral,
				},
			},
		},
		ArtifactFamilies: []provider.ArtifactFamily{
			provider.ArtifactFamilyGenericTURN,
		},
		CapabilityHints: provider.ProviderCapabilityHints{
			PotentialActions: []provider.ArtifactAction{
				provider.ArtifactActionStartOnThisDevice,
				provider.ArtifactActionExportHandoff,
			},
			RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
		},
	}
}

func invalidProviderSettingsTestDescriptor(providerID string) provider.ProviderDescriptor {
	return provider.ProviderDescriptor{
		ID:            providerID,
		DisplayName:   "Invalid schema provider",
		InputKind:     provider.ProviderInputKindLink,
		AuthPosture:   provider.ProviderAuthPostureAccount,
		BrowserPolicy: provider.ProviderBrowserPolicyNotRequired,
		SettingsSchema: &provider.ProviderSettingsSchema{
			Type:                 "object",
			AdditionalProperties: false,
			Properties: map[string]provider.ProviderSettingProperty{
				"device_pin": {
					Type:        provider.ProviderSettingTypeString,
					Title:       "Device PIN",
					WriteOnly:   true,
					Control:     provider.ProviderSettingControlPassword,
					Persistence: provider.ProviderSettingPersistenceProfile,
				},
			},
		},
		ArtifactFamilies: []provider.ArtifactFamily{
			provider.ArtifactFamilyGenericTURN,
		},
		CapabilityHints: provider.ProviderCapabilityHints{
			RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
		},
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
