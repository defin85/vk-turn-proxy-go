package clientcontrol

import (
	"bytes"
	"context"
	"encoding/json"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/transport"
)

func TestHandlerHostAndNegotiate(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(BuildIdentity{
			Product:     "vk-turn-proxy-go",
			Version:     "0.1.0",
			BuildNumber: "1",
			Revision:    "deadbeefcafe",
			Dirty:       true,
			BuiltAt:     "2026-04-07T12:00:00Z",
			Role:        "clientd",
			Target:      "linux/amd64",
		}),
	)
	handler := Handler(host)

	req := httptest.NewRequest(http.MethodGet, "/v1/host", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/host code = %d", rec.Code)
	}
	var info HostInfo
	if err := json.Unmarshal(rec.Body.Bytes(), &info); err != nil {
		t.Fatalf("decode host info: %v", err)
	}
	if info.Version != ContractVersion {
		t.Fatalf("version = %q, want %q", info.Version, ContractVersion)
	}
	if info.ContractVersion != ContractVersion {
		t.Fatalf("contract_version = %q, want %q", info.ContractVersion, ContractVersion)
	}
	if info.Build.Version != "0.1.0" {
		t.Fatalf("build version = %q, want 0.1.0", info.Build.Version)
	}
	if !containsCapability(info.Capabilities, CapabilityPlatformTunnels) {
		t.Fatalf("capabilities = %v, want platform_tunnels", info.Capabilities)
	}
	if !containsCapability(info.Capabilities, CapabilityProviderConfigs) {
		t.Fatalf("capabilities = %v, want provider_configs", info.Capabilities)
	}
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	if info.PlatformTunnels[0].Mode != PlatformTunnelModeLinuxTun {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", info.PlatformTunnels[0].Mode, PlatformTunnelModeLinuxTun)
	}

	body, _ := json.Marshal(NegotiateRequest{
		SupportedVersions: []string{ContractVersion},
		RequiredCapabilities: []Capability{
			CapabilityMobileHostBridge,
			CapabilityPlatformTunnels,
			CapabilityProfiles,
			CapabilityProviderConfigs,
			CapabilityProviderRuntimeArtifacts,
			CapabilitySessions,
			CapabilityChallenges,
			CapabilityDiagnostics,
			CapabilityEventStream,
		},
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/negotiate", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/negotiate code = %d body=%s", rec.Code, rec.Body.String())
	}

	req = httptest.NewRequest(http.MethodGet, "/v1/providers", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/providers code = %d body=%s", rec.Code, rec.Body.String())
	}
	var providers []ProviderDescriptor
	if err := json.Unmarshal(rec.Body.Bytes(), &providers); err != nil {
		t.Fatalf("decode providers: %v", err)
	}
	if len(providers) != 2 {
		t.Fatalf("providers len = %d, want 2", len(providers))
	}
	if providers[0].ID != "generic-turn" || providers[1].ID != "vk" {
		t.Fatalf("providers order = %+v, want generic-turn,vk", providers)
	}
	if providers[1].BrowserPolicy != ProviderBrowserPolicyExternalRequired {
		t.Fatalf("providers[1].browser_policy = %q, want %q", providers[1].BrowserPolicy, ProviderBrowserPolicyExternalRequired)
	}

	body, _ = json.Marshal(PlatformTunnelStartRequest{Mode: PlatformTunnelModeLinuxTun})
	req = httptest.NewRequest(http.MethodPost, "/v1/platform-tunnels/start", bytes.NewReader(body))
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/start code = %d body=%s", rec.Code, rec.Body.String())
	}
	var startResult PlatformTunnelStartResult
	if err := json.Unmarshal(rec.Body.Bytes(), &startResult); err != nil {
		t.Fatalf("decode platform tunnel start result: %v", err)
	}
	if startResult.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if startResult.Stage != PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("platform tunnel start stage = %q, want %q", startResult.Stage, PlatformTunnelStartupStageCapabilityCheck)
	}
}

func TestHandlerProvidersExposeProviderSettingsSchema(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{}, nil
			},
		})),
	)
	handler := Handler(host)

	req := httptest.NewRequest(http.MethodGet, "/v1/providers", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/providers code = %d body=%s", rec.Code, rec.Body.String())
	}

	var providers []ProviderDescriptor
	if err := json.Unmarshal(rec.Body.Bytes(), &providers); err != nil {
		t.Fatalf("decode providers: %v", err)
	}
	if len(providers) != 1 {
		t.Fatalf("providers len = %d, want 1", len(providers))
	}
	if providers[0].SettingsSchema == nil {
		t.Fatal("provider settings schema missing from /v1/providers response")
	}
	if got := providers[0].SettingsSchema.Properties["region"].Title; got != "Region" {
		t.Fatalf("provider settings schema region title = %q, want Region", got)
	}
}

func TestHandlerProvidersOmitInvalidProviderSettingsSchema(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "invalid-schema-provider",
			descriptor: invalidProviderSettingsTestDescriptor("invalid-schema-provider"),
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{}, nil
			},
		})),
	)
	handler := Handler(host)

	req := httptest.NewRequest(http.MethodGet, "/v1/providers", nil)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/providers code = %d body=%s", rec.Code, rec.Body.String())
	}

	var providers []ProviderDescriptor
	if err := json.Unmarshal(rec.Body.Bytes(), &providers); err != nil {
		t.Fatalf("decode providers: %v", err)
	}
	if len(providers) != 1 {
		t.Fatalf("providers len = %d, want 1", len(providers))
	}
	if providers[0].SettingsSchema != nil {
		t.Fatalf("provider settings schema = %#v, want nil for invalid descriptor schema", providers[0].SettingsSchema)
	}
}

func TestHandlerProfileUpsertReturnsFieldAwareProviderSettingsFailure(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{}, nil
			},
		})),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(Profile{
		ID:   "profile-1",
		Name: "settings",
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
	req := httptest.NewRequest(http.MethodPost, "/v1/profiles", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("POST /v1/profiles code = %d body=%s", rec.Code, rec.Body.String())
	}

	var errPayload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &errPayload); err != nil {
		t.Fatalf("decode error payload: %v", err)
	}
	if got := errPayload["code"]; got != "provider_settings_invalid" {
		t.Fatalf("error code = %v, want provider_settings_invalid", got)
	}
	if got := errPayload["field"]; got != "device_pin" {
		t.Fatalf("error field = %v, want device_pin", got)
	}
	if got := errPayload["violation"]; got != providerSettingsViolationPersistence {
		t.Fatalf("error violation = %v, want %s", got, providerSettingsViolationPersistence)
	}
}

func TestHandlerProviderConfigLifecycle(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
		})),
		withNow(func() time.Time {
			return time.Date(2026, 4, 13, 10, 15, 0, 0, time.UTC)
		}),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(ProviderConfig{
		Name:     "EU guest",
		Provider: "schema-provider",
		ProviderSettings: ProviderSettings{
			"region":       "eu-west",
			"device_index": 2,
		},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/provider-configs", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/provider-configs code = %d body=%s", rec.Code, rec.Body.String())
	}

	var saved ProviderConfig
	if err := json.Unmarshal(rec.Body.Bytes(), &saved); err != nil {
		t.Fatalf("decode provider config: %v", err)
	}
	if saved.ID == "" {
		t.Fatal("saved provider config id is empty")
	}
	if saved.Availability.State != ProviderConfigAvailabilityAvailable {
		t.Fatalf("saved availability = %q, want %q", saved.Availability.State, ProviderConfigAvailabilityAvailable)
	}

	req = httptest.NewRequest(http.MethodGet, "/v1/provider-configs", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/provider-configs code = %d body=%s", rec.Code, rec.Body.String())
	}

	var listed []ProviderConfig
	if err := json.Unmarshal(rec.Body.Bytes(), &listed); err != nil {
		t.Fatalf("decode provider configs: %v", err)
	}
	if len(listed) != 1 {
		t.Fatalf("provider configs len = %d, want 1", len(listed))
	}
	if listed[0].ID != saved.ID {
		t.Fatalf("listed provider config id = %q, want %q", listed[0].ID, saved.ID)
	}

	req = httptest.NewRequest(http.MethodDelete, "/v1/provider-configs/"+saved.ID, nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Fatalf("DELETE /v1/provider-configs/{id} code = %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestHandlerProviderConfigReturnsFieldAwareProviderSettingsFailure(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
		})),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(ProviderConfig{
		Name:     "Prompt-only",
		Provider: "schema-provider",
		ProviderSettings: ProviderSettings{
			"region":     "eu-west",
			"device_pin": "123456",
		},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/provider-configs", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("POST /v1/provider-configs code = %d body=%s", rec.Code, rec.Body.String())
	}

	var errPayload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &errPayload); err != nil {
		t.Fatalf("decode error payload: %v", err)
	}
	if got := errPayload["code"]; got != "provider_settings_invalid" {
		t.Fatalf("error code = %v, want provider_settings_invalid", got)
	}
	if got := errPayload["field"]; got != "device_pin" {
		t.Fatalf("error field = %v, want device_pin", got)
	}
	if got := errPayload["violation"]; got != providerSettingsViolationPersistence {
		t.Fatalf("error violation = %v, want %s", got, providerSettingsViolationPersistence)
	}
}

func TestHandlerProviderConfigRestoreKeepsUnavailableRecordExplicit(t *testing.T) {
	host := New(WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))))
	handler := Handler(host)

	restoredAt := time.Date(2026, 4, 13, 10, 15, 0, 0, time.UTC)
	payload, _ := json.Marshal(ProviderConfig{
		ID:       "cfg-1",
		Name:     "Legacy WB config",
		Provider: "wb-stream",
		ProviderSettings: ProviderSettings{
			"region": "eu-west",
		},
		CreatedAt: restoredAt,
		UpdatedAt: restoredAt,
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/provider-configs", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/provider-configs restore code = %d body=%s", rec.Code, rec.Body.String())
	}

	var saved ProviderConfig
	if err := json.Unmarshal(rec.Body.Bytes(), &saved); err != nil {
		t.Fatalf("decode provider config: %v", err)
	}
	if saved.Availability.State != ProviderConfigAvailabilityProviderUnavailable {
		t.Fatalf("saved availability = %q, want %q", saved.Availability.State, ProviderConfigAvailabilityProviderUnavailable)
	}
}

func TestHandlerProfileUpsertAcceptsPersistedProfileWithoutSecretLink(t *testing.T) {
	host := New(WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))))
	handler := Handler(host)

	payload, _ := json.Marshal(Profile{
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
	req := httptest.NewRequest(http.MethodPost, "/v1/profiles", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/profiles code = %d body=%s", rec.Code, rec.Body.String())
	}

	var profile Profile
	if err := json.Unmarshal(rec.Body.Bytes(), &profile); err != nil {
		t.Fatalf("decode profile: %v", err)
	}
	if profile.Spec.Link != "" {
		t.Fatalf("persisted profile link = %q, want empty redacted value", profile.Spec.Link)
	}
}

func TestHandlerStartResolutionReturnsFieldAwareProviderSettingsFailure(t *testing.T) {
	host := New(
		withRegistry(provider.NewRegistry(fakeAdapter{
			name:       "schema-provider",
			descriptor: providerSettingsTestDescriptor("schema-provider"),
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{}, nil
			},
		})),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(StartResolutionRequest{
		Provider: "schema-provider",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://example.test/invite/abc",
		},
		ProviderSettings: ProviderSettings{"device_pin": "123456"},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/resolutions", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("POST /v1/resolutions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var errPayload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &errPayload); err != nil {
		t.Fatalf("decode error payload: %v", err)
	}
	if got := errPayload["code"]; got != "provider_settings_invalid" {
		t.Fatalf("error code = %v, want provider_settings_invalid", got)
	}
	if got := errPayload["field"]; got != "region" {
		t.Fatalf("error field = %v, want region", got)
	}
	if got := errPayload["violation"]; got != providerSettingsViolationRequired {
		t.Fatalf("error violation = %v, want %s", got, providerSettingsViolationRequired)
	}
}

func TestHandlerResolutionLifecycle(t *testing.T) {
	now := time.Date(2026, 4, 10, 12, 0, 0, 0, time.UTC)
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withNow(func() time.Time { return now }),
		WithSessionIDSource(func() string { return "resolution-http-session" }),
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
	handler := Handler(host)

	payload, _ := json.Marshal(StartResolutionRequest{
		Provider: "vk",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://vk.com/call/join/test-token",
		},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/resolutions", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/resolutions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var resolutionState Resolution
	if err := json.Unmarshal(rec.Body.Bytes(), &resolutionState); err != nil {
		t.Fatalf("decode resolution response: %v", err)
	}
	resolutionState = waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)
	if resolutionState.Input.Kind != ProviderInputKindLink {
		t.Fatalf("resolution input kind = %q, want %q", resolutionState.Input.Kind, ProviderInputKindLink)
	}
	if resolutionState.Artifact == nil {
		t.Fatal("resolution artifact missing")
	}
	if resolutionState.Artifact.Family != ArtifactFamilyGenericTURN {
		t.Fatalf("resolution artifact family = %q, want %q", resolutionState.Artifact.Family, ArtifactFamilyGenericTURN)
	}
	if len(resolutionState.Artifact.Actions) != 2 {
		t.Fatalf("resolution artifact actions len = %d, want 2", len(resolutionState.Artifact.Actions))
	}
	if resolutionState.Artifact.Actions[0].ExecutionOwner != ActionExecutionOwnerHost {
		t.Fatalf("resolution artifact action[0].execution_owner = %q, want %q", resolutionState.Artifact.Actions[0].ExecutionOwner, ActionExecutionOwnerHost)
	}

	req = httptest.NewRequest(http.MethodGet, "/v1/resolutions/"+resolutionState.ID, nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /v1/resolutions/{id} code = %d body=%s", rec.Code, rec.Body.String())
	}
	if bytes.Contains(rec.Body.Bytes(), []byte("turn-user:turn-pass@")) {
		t.Fatalf("GET /v1/resolutions/{id} leaked secret: %s", rec.Body.String())
	}
	if !bytes.Contains(rec.Body.Bytes(), []byte(`"family":"generic_turn"`)) {
		t.Fatalf("GET /v1/resolutions/{id} missing generic_turn artifact: %s", rec.Body.String())
	}

	req = httptest.NewRequest(http.MethodPost, "/v1/resolutions/"+resolutionState.ID+"/export", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/resolutions/{id}/export code = %d body=%s", rec.Code, rec.Body.String())
	}
	var exportResult ResolutionExportResult
	if err := json.Unmarshal(rec.Body.Bytes(), &exportResult); err != nil {
		t.Fatalf("decode resolution export response: %v", err)
	}
	if exportResult.Link != "generic-turn://turn-user:turn-pass@turn.example.test:3478" {
		t.Fatalf("export link = %q", exportResult.Link)
	}
	if exportResult.ExpirySource != "turn_rest_username" {
		t.Fatalf("export expiry_source = %q, want turn_rest_username", exportResult.ExpirySource)
	}

	payload, _ = json.Marshal(MaterializeResolutionRequest{
		RuntimeDefaults: RuntimeDefaults{
			ListenAddr:  reserveUDPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(true),
		},
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/resolutions/"+resolutionState.ID+"/materialize", bytes.NewReader(payload))
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/resolutions/{id}/materialize code = %d body=%s", rec.Code, rec.Body.String())
	}
	var sessionState Session
	if err := json.Unmarshal(rec.Body.Bytes(), &sessionState); err != nil {
		t.Fatalf("decode materialized session response: %v", err)
	}
	if sessionState.SourceResolutionID != resolutionState.ID {
		t.Fatalf("materialized session source_resolution_id = %q, want %q", sessionState.SourceResolutionID, resolutionState.ID)
	}
}

func TestHandlerPlatformTunnelStartReturnsTypedFailureResult(t *testing.T) {
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
			return PlatformTunnelStartResult{}, &PlatformTunnelStartError{
				Result: PlatformTunnelStartResult{
					Mode:                req.Mode,
					Ready:               false,
					Stage:               PlatformTunnelStartupStageRuntimeAttach,
					MissingPrerequisite: PlatformTunnelPrerequisiteDNSBypass,
					Message:             "runtime attach left the host without required DNS bypass",
				},
			}
		}),
	)
	handler := Handler(host)

	body, _ := json.Marshal(PlatformTunnelStartRequest{Mode: PlatformTunnelModeLinuxTun})
	req := httptest.NewRequest(http.MethodPost, "/v1/platform-tunnels/start", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/start code = %d body=%s", rec.Code, rec.Body.String())
	}

	var result PlatformTunnelStartResult
	if err := json.Unmarshal(rec.Body.Bytes(), &result); err != nil {
		t.Fatalf("decode platform tunnel start result: %v", err)
	}
	if result.Ready {
		t.Fatal("platform tunnel typed failure ready = true, want false")
	}
	if result.Stage != PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("platform tunnel typed failure stage = %q, want %q", result.Stage, PlatformTunnelStartupStageRuntimeAttach)
	}
	if result.MissingPrerequisite != PlatformTunnelPrerequisiteDNSBypass {
		t.Fatalf("platform tunnel typed failure missing_prerequisite = %q, want %q", result.MissingPrerequisite, PlatformTunnelPrerequisiteDNSBypass)
	}
}

func TestHandlerPlatformTunnelStartRejectsInvalidTypedFailureResult(t *testing.T) {
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
			return PlatformTunnelStartResult{}, &PlatformTunnelStartError{
				Result: PlatformTunnelStartResult{
					Mode:  req.Mode,
					Ready: false,
				},
			}
		}),
	)
	handler := Handler(host)

	body, _ := json.Marshal(PlatformTunnelStartRequest{Mode: PlatformTunnelModeLinuxTun})
	req := httptest.NewRequest(http.MethodPost, "/v1/platform-tunnels/start", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("POST /v1/platform-tunnels/start code = %d body=%s, want 500", rec.Code, rec.Body.String())
	}

	var payload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode platform tunnel error payload: %v", err)
	}
	if payload["code"] != "platform_tunnel_start_failed" {
		t.Fatalf("platform tunnel error code = %v, want platform_tunnel_start_failed", payload["code"])
	}
}

func TestHandlerPlatformTunnelStartRejectsTypedFailureWithoutMissingPrerequisite(t *testing.T) {
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
			return PlatformTunnelStartResult{}, &PlatformTunnelStartError{
				Result: PlatformTunnelStartResult{
					Mode:    req.Mode,
					Ready:   false,
					Stage:   PlatformTunnelStartupStageRuntimeAttach,
					Message: "runtime attach failed without missing_prerequisite",
				},
			}
		}),
	)
	handler := Handler(host)

	body, _ := json.Marshal(PlatformTunnelStartRequest{Mode: PlatformTunnelModeLinuxTun})
	req := httptest.NewRequest(http.MethodPost, "/v1/platform-tunnels/start", bytes.NewReader(body))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("POST /v1/platform-tunnels/start code = %d body=%s, want 500", rec.Code, rec.Body.String())
	}

	var payload map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payload); err != nil {
		t.Fatalf("decode platform tunnel error payload: %v", err)
	}
	if payload["code"] != "platform_tunnel_start_failed" {
		t.Fatalf("platform tunnel error code = %v, want platform_tunnel_start_failed", payload["code"])
	}
}

func TestHandlerSessionDiagnosticsAndMetrics(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(BuildIdentity{
			Product:     "vk-turn-proxy-go",
			Version:     "0.1.0",
			BuildNumber: "1",
			Revision:    "deadbeefcafe",
			Dirty:       true,
			BuiltAt:     "2026-04-07T12:00:00Z",
			Role:        "clientd",
			Target:      "linux/amd64",
		}),
		WithSessionIDSource(func() string { return "session-http" }),
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
				if cfg.Hooks.OnReady != nil {
					cfg.Hooks.OnReady()
				}
				if cfg.Hooks.OnTraffic != nil {
					cfg.Hooks.OnTraffic(transport.TrafficDirectionLocalToRelay, 5)
				}
				<-ctx.Done()
				return nil
			}}
		}),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(StartSessionRequest{
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
	req := httptest.NewRequest(http.MethodPost, "/v1/sessions", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/sessions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var sessionState Session
	if err := json.Unmarshal(rec.Body.Bytes(), &sessionState); err != nil {
		t.Fatalf("decode session response: %v", err)
	}

	waitForSessionState(t, host, sessionState.ID, SessionStateReady)

	req = httptest.NewRequest(http.MethodGet, "/v1/sessions/"+sessionState.ID+"/diagnostics", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET diagnostics code = %d body=%s", rec.Code, rec.Body.String())
	}
	var diagnostics Diagnostics
	if err := json.Unmarshal(rec.Body.Bytes(), &diagnostics); err != nil {
		t.Fatalf("decode diagnostics: %v", err)
	}
	if diagnostics.Session.ID != sessionState.ID {
		t.Fatalf("diagnostics session_id = %q, want %q", diagnostics.Session.ID, sessionState.ID)
	}
	if diagnostics.ContractVersion != ContractVersion {
		t.Fatalf("diagnostics contract_version = %q, want %q", diagnostics.ContractVersion, ContractVersion)
	}
	if diagnostics.HostBuild.Version != "0.1.0" {
		t.Fatalf("diagnostics host build version = %q, want 0.1.0", diagnostics.HostBuild.Version)
	}

	metricsHandler, err := host.MetricsHandler(sessionState.ID)
	if err != nil {
		t.Fatalf("MetricsHandler() error = %v", err)
	}
	req = httptest.NewRequest(http.MethodGet, "/metrics", nil)
	rec = httptest.NewRecorder()
	metricsHandler.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /metrics code = %d body=%s", rec.Code, rec.Body.String())
	}
	if !bytes.Contains(rec.Body.Bytes(), []byte("vk_turn_proxy_runtime_session_starts_total")) {
		t.Fatalf("metrics output missing session starts: %s", rec.Body.String())
	}

	if _, err := host.StopSession(sessionState.ID); err != nil {
		t.Fatalf("StopSession() error = %v", err)
	}
	if _, err := host.WaitSession(context.Background(), sessionState.ID); err != nil {
		t.Fatalf("WaitSession() error = %v", err)
	}
}

func TestHandlerStartSessionOutlivesRequestContext(t *testing.T) {
	readyCh := make(chan struct{})
	releaseCh := make(chan struct{})
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithSessionIDSource(func() string { return "session-detached" }),
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
				select {
				case <-ctx.Done():
					return ctx.Err()
				case <-releaseCh:
				}
				if cfg.Hooks.OnReady != nil {
					cfg.Hooks.OnReady()
				}
				close(readyCh)
				<-ctx.Done()
				return nil
			}}
		}),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(StartSessionRequest{
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
	reqCtx, cancelReq := context.WithCancel(context.Background())
	req := httptest.NewRequest(http.MethodPost, "/v1/sessions", bytes.NewReader(payload)).WithContext(reqCtx)
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/sessions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var sessionState Session
	if err := json.Unmarshal(rec.Body.Bytes(), &sessionState); err != nil {
		t.Fatalf("decode session response: %v", err)
	}

	cancelReq()
	close(releaseCh)

	select {
	case <-readyCh:
	case <-time.After(3 * time.Second):
		t.Fatal("session did not outlive request context cancellation")
	}

	waitForSessionState(t, host, sessionState.ID, SessionStateReady)

	if _, err := host.StopSession(sessionState.ID); err != nil {
		t.Fatalf("StopSession() error = %v", err)
	}
	if _, err := host.WaitSession(context.Background(), sessionState.ID); err != nil {
		t.Fatalf("WaitSession() error = %v", err)
	}
}

func TestEventsStreamFlushesHeadersWithoutEvents(t *testing.T) {
	t.Parallel()

	server := httptest.NewServer(Handler(New()))
	t.Cleanup(server.Close)

	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Get(server.URL + "/v1/events")
	if err != nil {
		t.Fatalf("GET /v1/events error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /v1/events status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	if got := resp.Header.Get("Content-Type"); got != "application/x-ndjson" {
		t.Fatalf("GET /v1/events content-type = %q, want %q", got, "application/x-ndjson")
	}
}

func TestHandlerResolutionExportFailureIncludesTypedAction(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "roomy",
			descriptor: provider.ProviderDescriptor{
				ID:               "roomy",
				DisplayName:      "Roomy",
				InputKind:        provider.ProviderInputKindLink,
				AuthPosture:      provider.ProviderAuthPostureNotApplicable,
				BrowserPolicy:    provider.ProviderBrowserPolicyNotRequired,
				ArtifactFamilies: []provider.ArtifactFamily{provider.ArtifactFamilyConferenceRoom},
				CapabilityHints: provider.ProviderCapabilityHints{
					PotentialActions: []provider.ArtifactAction{
						provider.ArtifactActionOpenRoom,
					},
					RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
				},
			},
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Artifact: &provider.ProbeArtifact{
						Outcome: provider.ProbeArtifactOutcome{
							ResultKind: "conference_room",
							ConferenceRoom: &provider.ProbeArtifactConferenceRoom{
								RoomURL: "https://room.example.test/rooms/team-sync",
							},
						},
					},
					Metadata: map[string]string{
						"provider":          "roomy",
						"resolution_method": "room",
					},
				}, nil
			},
		})),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(StartResolutionRequest{
		Provider: "roomy",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://room.example.test/join/token",
		},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/resolutions", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/resolutions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var resolutionState Resolution
	if err := json.Unmarshal(rec.Body.Bytes(), &resolutionState); err != nil {
		t.Fatalf("decode resolution response: %v", err)
	}
	resolutionState = waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)

	req = httptest.NewRequest(http.MethodPost, "/v1/resolutions/"+resolutionState.ID+"/export", nil)
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusConflict {
		t.Fatalf("POST /v1/resolutions/{id}/export code = %d body=%s", rec.Code, rec.Body.String())
	}

	var payloadBody map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payloadBody); err != nil {
		t.Fatalf("decode export error response: %v", err)
	}
	if payloadBody["code"] != "resolution_export_unavailable" {
		t.Fatalf("error code = %#v, want resolution_export_unavailable", payloadBody["code"])
	}
	if payloadBody["action"] != string(ArtifactActionExportHandoff) {
		t.Fatalf("error action = %#v, want %q", payloadBody["action"], ArtifactActionExportHandoff)
	}
}

func TestHandlerResolutionMaterializeFailureIncludesTypedAction(t *testing.T) {
	host := New(
		WithLogger(slog.New(slog.NewTextHandler(io.Discard, nil))),
		WithBuildIdentity(testBuildIdentity()),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "roomy",
			descriptor: provider.ProviderDescriptor{
				ID:               "roomy",
				DisplayName:      "Roomy",
				InputKind:        provider.ProviderInputKindLink,
				AuthPosture:      provider.ProviderAuthPostureNotApplicable,
				BrowserPolicy:    provider.ProviderBrowserPolicyNotRequired,
				ArtifactFamilies: []provider.ArtifactFamily{provider.ArtifactFamilyConferenceRoom},
				CapabilityHints: provider.ProviderCapabilityHints{
					PotentialActions: []provider.ArtifactAction{
						provider.ArtifactActionOpenRoom,
					},
					RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
				},
			},
			resolve: func(ctx context.Context, link string) (provider.Resolution, error) {
				return provider.Resolution{
					Artifact: &provider.ProbeArtifact{
						Outcome: provider.ProbeArtifactOutcome{
							ResultKind: "conference_room",
							ConferenceRoom: &provider.ProbeArtifactConferenceRoom{
								RoomURL: "https://room.example.test/rooms/team-sync",
							},
						},
					},
					Metadata: map[string]string{
						"provider":          "roomy",
						"resolution_method": "room",
					},
				}, nil
			},
		})),
	)
	handler := Handler(host)

	payload, _ := json.Marshal(StartResolutionRequest{
		Provider: "roomy",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "https://room.example.test/join/token",
		},
	})
	req := httptest.NewRequest(http.MethodPost, "/v1/resolutions", bytes.NewReader(payload))
	rec := httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusAccepted {
		t.Fatalf("POST /v1/resolutions code = %d body=%s", rec.Code, rec.Body.String())
	}

	var resolutionState Resolution
	if err := json.Unmarshal(rec.Body.Bytes(), &resolutionState); err != nil {
		t.Fatalf("decode resolution response: %v", err)
	}
	resolutionState = waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)

	payload, _ = json.Marshal(MaterializeResolutionRequest{
		RuntimeDefaults: RuntimeDefaults{
			ListenAddr:  reserveUDPAddr(t),
			PeerAddr:    "127.0.0.1:56000",
			Connections: 1,
			Mode:        TransportModeAuto,
			UseDTLS:     boolRef(true),
		},
	})
	req = httptest.NewRequest(http.MethodPost, "/v1/resolutions/"+resolutionState.ID+"/materialize", bytes.NewReader(payload))
	rec = httptest.NewRecorder()
	handler.ServeHTTP(rec, req)
	if rec.Code != http.StatusConflict {
		t.Fatalf("POST /v1/resolutions/{id}/materialize code = %d body=%s", rec.Code, rec.Body.String())
	}

	var payloadBody map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &payloadBody); err != nil {
		t.Fatalf("decode materialize error response: %v", err)
	}
	if payloadBody["code"] != "resolution_materialize_unavailable" {
		t.Fatalf("error code = %#v, want resolution_materialize_unavailable", payloadBody["code"])
	}
	if payloadBody["action"] != string(ArtifactActionStartOnThisDevice) {
		t.Fatalf("error action = %#v, want %q", payloadBody["action"], ArtifactActionStartOnThisDevice)
	}
}
