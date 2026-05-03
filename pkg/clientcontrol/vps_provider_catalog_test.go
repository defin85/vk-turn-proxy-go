package clientcontrol

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/vpscatalog"
)

func TestVPSProviderCatalogCapabilitySyncAndSources(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	server := testVPSCatalogServer(t, testClientVPSCatalogSnapshot(now), &now)
	host := testVPSCatalogHost(t, server.URL, &now)

	info := host.Info()
	if !testContainsCapability(info.Capabilities, CapabilityVPSProviderCatalogs) {
		t.Fatalf("capabilities = %v, want %s", info.Capabilities, CapabilityVPSProviderCatalogs)
	}
	if info.VPSProviderCatalogs == nil ||
		info.VPSProviderCatalogs.SyncEndpoint != vpsProviderCatalogSyncEndpoint ||
		info.VPSProviderCatalogs.ArtifactIssueEndpoint != vpsProviderCatalogIssueEndpoint {
		t.Fatalf("vps provider catalog capability = %+v, want sync and issue endpoints", info.VPSProviderCatalogs)
	}
	infoBody, err := json.Marshal(info)
	if err != nil {
		t.Fatalf("Marshal(info) error = %v", err)
	}
	if strings.Contains(string(infoBody), "read-token") || strings.Contains(string(infoBody), "issue-token") {
		t.Fatalf("host info leaked catalog tokens: %s", infoBody)
	}

	statuses, err := host.SyncVPSProviderCatalogs(context.Background())
	if err != nil {
		t.Fatalf("SyncVPSProviderCatalogs() error = %v", err)
	}
	if len(statuses) != 1 || statuses[0].ValidationStatus != string(vpscatalog.ValidationStatusValid) {
		t.Fatalf("sync statuses = %+v, want one valid status", statuses)
	}

	sources := host.RemoteProviderSources()
	if len(sources) != 1 {
		t.Fatalf("remote sources len = %d, want 1: %+v", len(sources), sources)
	}
	source := sources[0]
	if source.EndpointID != "vps-main" ||
		source.ProviderID != "generic-turn" ||
		source.ValidationStatus != string(vpscatalog.ValidationStatusValid) ||
		len(source.ArtifactOffers) != 1 ||
		source.ArtifactOffers[0].ValidationStatus != string(vpscatalog.ValidationStatusValid) {
		t.Fatalf("remote source = %+v, want valid generic-turn offer", source)
	}
	sourcesBody, err := json.Marshal(sources)
	if err != nil {
		t.Fatalf("Marshal(sources) error = %v", err)
	}
	if strings.Contains(string(sourcesBody), "read-token") ||
		strings.Contains(string(sourcesBody), "issue-token") ||
		strings.Contains(string(sourcesBody), "turn-pass") {
		t.Fatalf("remote provider sources leaked secret material: %s", sourcesBody)
	}
}

func TestVPSProviderCatalogIssueMapsRemoteArtifactAndCompatibility(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	server := testVPSCatalogServer(t, testClientVPSCatalogSnapshot(now), &now)
	host := testVPSCatalogHost(t, server.URL, &now)
	if _, err := host.SyncVPSProviderCatalogs(context.Background()); err != nil {
		t.Fatalf("SyncVPSProviderCatalogs() error = %v", err)
	}

	result, err := host.IssueVPSProviderArtifact(context.Background(), VPSProviderArtifactIssueRequest{
		EndpointID:  "vps-main",
		SourceID:    "managed-turn",
		OfferID:     "turn-handoff",
		OperationID: "op-clientcontrol",
		TTLSeconds:  45,
	})
	if err != nil {
		t.Fatalf("IssueVPSProviderArtifact() error = %v", err)
	}
	if result.Resolution.Provider != "generic-turn" ||
		result.Resolution.Input.Kind != ProviderInputKindRemoteVPSCatalog ||
		result.Resolution.RemoteVPS == nil ||
		result.Resolution.Artifact == nil ||
		result.Resolution.Artifact.Summary.RemoteVPS == nil {
		t.Fatalf("issued resolution = %+v, want typed remote VPS artifact", result.Resolution)
	}
	if result.Resolution.Credentials != nil || result.Resolution.Export.Supported {
		t.Fatalf("issued resolution exposed local credentials/export: %+v", result.Resolution)
	}
	body, err := json.Marshal(result)
	if err != nil {
		t.Fatalf("Marshal(result) error = %v", err)
	}
	if strings.Contains(string(body), "read-token") ||
		strings.Contains(string(body), "issue-token") ||
		strings.Contains(string(body), "turn-pass") {
		t.Fatalf("issued result leaked secret material: %s", body)
	}

	descriptor := testStrictWireGuardTurnDescriptor()
	noProfile := onlyCompatibilityCandidate(t, host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  result.Resolution.ID,
		ExecutionPlan: &descriptor.Plan,
	}))
	if noProfile.Status != ProviderTransportCompatibilityStatusSetupNeeded ||
		noProfile.ReasonCode != ProviderTransportCompatibilityReasonTransportProfileRequired {
		t.Fatalf("candidate without profile = %+v, want explicit transport profile requirement", noProfile)
	}

	profile, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("remote-vps-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	startable := onlyCompatibilityCandidate(t, host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  result.Resolution.ID,
		ExecutionPlan: &descriptor.Plan,
		TransportProfile: &TransportProfileReference{
			ProfileID: profile.ID,
			Kind:      profile.Kind,
		},
	}))
	if startable.Status != ProviderTransportCompatibilityStatusStartable || !startable.Startable {
		t.Fatalf("candidate with explicit profile = %+v, want startable", startable)
	}
}

func TestVPSProviderCatalogHTTPExposesSyncSourcesAndIssue(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	server := testVPSCatalogServer(t, testClientVPSCatalogSnapshot(now), &now)
	host := testVPSCatalogHost(t, server.URL, &now)
	control := httptest.NewServer(Handler(host))
	t.Cleanup(control.Close)

	resp, err := http.Post(control.URL+vpsProviderCatalogSyncEndpoint, "application/json", http.NoBody)
	if err != nil {
		t.Fatalf("POST sync error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST sync status = %d, want 200", resp.StatusCode)
	}
	var statuses []VPSProviderCatalogStatus
	if err := json.NewDecoder(resp.Body).Decode(&statuses); err != nil {
		t.Fatalf("decode sync statuses: %v", err)
	}
	if len(statuses) != 1 || statuses[0].ValidationStatus != string(vpscatalog.ValidationStatusValid) {
		t.Fatalf("sync statuses = %+v, want valid", statuses)
	}

	resp, err = http.Get(control.URL + "/v1/provider-sources")
	if err != nil {
		t.Fatalf("GET provider sources error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET provider sources status = %d, want 200", resp.StatusCode)
	}
	var sources []RemoteProviderSourceDescriptor
	if err := json.NewDecoder(resp.Body).Decode(&sources); err != nil {
		t.Fatalf("decode provider sources: %v", err)
	}
	if len(sources) != 1 || sources[0].SourceID != "managed-turn" {
		t.Fatalf("provider sources = %+v, want managed-turn", sources)
	}

	body, _ := json.Marshal(VPSProviderArtifactIssueRequest{
		EndpointID:  "vps-main",
		SourceID:    "managed-turn",
		OfferID:     "turn-handoff",
		OperationID: "op-http",
	})
	resp, err = http.Post(
		control.URL+vpsProviderCatalogIssueEndpoint,
		"application/json",
		bytes.NewReader(body),
	)
	if err != nil {
		t.Fatalf("POST issue error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST issue status = %d, want 200", resp.StatusCode)
	}
	var result VPSProviderArtifactIssueResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode issue result: %v", err)
	}
	if result.Resolution.RemoteVPS == nil || result.RemoteArtifact.SourceID != "managed-turn" {
		t.Fatalf("issue result = %+v, want remote VPS artifact", result)
	}
}

func TestVPSProviderCatalogSyncRejectsRollbackAndStaleCacheFailsClosed(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	handler := &mutableHTTPHandler{}
	server := httptest.NewServer(handler)
	t.Cleanup(server.Close)

	gen2 := testClientVPSCatalogSnapshot(now)
	handler.set(testVPSCatalogService(gen2, &now).Handler())
	host := testVPSCatalogHost(t, server.URL, &now)
	if _, err := host.SyncVPSProviderCatalogs(context.Background()); err != nil {
		t.Fatalf("initial SyncVPSProviderCatalogs() error = %v", err)
	}

	rollback := testClientVPSCatalogSnapshot(now)
	rollback.Generation = 1
	handler.set(testVPSCatalogService(rollback, &now).Handler())
	statuses, err := host.SyncVPSProviderCatalogs(context.Background())
	if !errors.Is(err, vpscatalog.ErrValidationFailed) {
		t.Fatalf("rollback SyncVPSProviderCatalogs() error = %v, want ErrValidationFailed", err)
	}
	if len(statuses) != 1 || statuses[0].ValidationStatus != string(vpscatalog.ValidationStatusRollback) {
		t.Fatalf("rollback statuses = %+v, want rollback", statuses)
	}
	if sources := host.RemoteProviderSources(); len(sources) != 0 {
		t.Fatalf("remote sources after rollback = %+v, want none", sources)
	}

	gen3 := testClientVPSCatalogSnapshot(now)
	gen3.Generation = 3
	handler.set(testVPSCatalogService(gen3, &now).Handler())
	if _, err := host.SyncVPSProviderCatalogs(context.Background()); err != nil {
		t.Fatalf("resync after rollback error = %v", err)
	}
	now = now.Add(11 * time.Minute)
	cached := host.VPSProviderCatalogs()
	if len(cached) != 1 || cached[0].ValidationStatus != string(vpscatalog.ValidationStatusStale) {
		t.Fatalf("stale cached statuses = %+v, want stale", cached)
	}
	_, err = host.IssueVPSProviderArtifact(context.Background(), VPSProviderArtifactIssueRequest{
		EndpointID:  "vps-main",
		SourceID:    "managed-turn",
		OfferID:     "turn-handoff",
		OperationID: "op-stale-cache",
	})
	if !errors.Is(err, ErrVPSProviderCatalogInvalid) {
		t.Fatalf("IssueVPSProviderArtifact(stale cache) error = %v, want ErrVPSProviderCatalogInvalid", err)
	}
}

func TestVPSProviderCatalogRemoteArtifactsFailCompatibilityOnEvidenceDrift(t *testing.T) {
	tests := []struct {
		name           string
		evidenceStatus vpscatalog.EvidenceStatus
		readiness      vpscatalog.ValidationStatus
		wantStatus     ProviderTransportCompatibilityStatus
		wantAxis       ProviderTransportCompatibilityFailingAxis
		wantReason     ProviderTransportCompatibilityReasonCode
	}{
		{
			name:           "missing evidence",
			evidenceStatus: vpscatalog.EvidenceStatusMissing,
			readiness:      vpscatalog.ValidationStatusMissingEvidence,
			wantStatus:     ProviderTransportCompatibilityStatusMissingEvidence,
			wantAxis:       ProviderTransportCompatibilityAxisEvidence,
			wantReason:     ProviderTransportCompatibilityReasonEvidenceMissing,
		},
		{
			name:           "stale evidence",
			evidenceStatus: vpscatalog.EvidenceStatusStale,
			readiness:      vpscatalog.ValidationStatusStale,
			wantStatus:     ProviderTransportCompatibilityStatusStale,
			wantAxis:       ProviderTransportCompatibilityAxisProviderArtifact,
			wantReason:     ProviderTransportCompatibilityReasonProviderArtifactStale,
		},
		{
			name:           "degraded evidence",
			evidenceStatus: vpscatalog.EvidenceStatusDegraded,
			readiness:      vpscatalog.ValidationStatusDegraded,
			wantStatus:     ProviderTransportCompatibilityStatusDegraded,
			wantAxis:       ProviderTransportCompatibilityAxisEvidence,
			wantReason:     ProviderTransportCompatibilityReasonProviderArtifactDegraded,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
			host := New(
				withNow(func() time.Time { return now }),
				WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
				WithVPNTransportProfileStore(),
				WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
			)
			snapshot := testClientVPSCatalogSnapshot(now)
			source := snapshot.Sources[0]
			offer := source.ArtifactOffers[0]
			response := testClientVPSArtifactIssueResponse(now, source, offer, tt.evidenceStatus)
			resolved, err := host.recordVPSIssuedResolution(
				VPSProviderArtifactIssueRequest{
					EndpointID:  "vps-main",
					SourceID:    source.ID,
					OfferID:     offer.ID,
					OperationID: "op-" + strings.ReplaceAll(tt.name, " ", "-"),
				},
				response,
				source,
				offer,
				vpscatalog.ValidationResult{
					Status:  tt.readiness,
					Reason:  string(tt.wantReason),
					Message: tt.name,
				},
			)
			if err != nil {
				t.Fatalf("recordVPSIssuedResolution() error = %v", err)
			}

			descriptor := testStrictWireGuardTurnDescriptor()
			candidate := onlyCompatibilityCandidate(t, host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
				ResolutionID:  resolved.ID,
				ExecutionPlan: &descriptor.Plan,
			}))
			if candidate.Status != tt.wantStatus ||
				candidate.FailingAxis != tt.wantAxis ||
				candidate.ReasonCode != tt.wantReason {
				t.Fatalf("remote artifact candidate = %+v, want status=%s axis=%s reason=%s", candidate, tt.wantStatus, tt.wantAxis, tt.wantReason)
			}
		})
	}
}

func testVPSCatalogHost(t *testing.T, baseURL string, now *time.Time) *Host {
	t.Helper()
	return New(
		withNow(func() time.Time { return *now }),
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
		WithVPSProviderCatalogEndpoints([]VPSProviderCatalogEndpointConfig{{
			ID:         "vps-main",
			URL:        baseURL,
			Issuer:     "vk-turn-proxy-go",
			Audience:   "relay-client",
			ReadToken:  "read-token",
			IssueToken: "issue-token",
		}}),
		WithVPSProviderCatalogHTTPClient(http.DefaultClient),
	)
}

func testVPSCatalogServer(
	t *testing.T,
	snapshot vpscatalog.CatalogSnapshot,
	now *time.Time,
) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(testVPSCatalogService(snapshot, now).Handler())
	t.Cleanup(server.Close)
	return server
}

func testVPSCatalogService(
	snapshot vpscatalog.CatalogSnapshot,
	now *time.Time,
) *vpscatalog.Service {
	return vpscatalog.NewService(vpscatalog.ServiceOptions{
		Snapshot: vpscatalog.AttachIntegrity(snapshot, "test"),
		Now:      func() time.Time { return *now },
		Authorizer: vpscatalog.TokenAuthorizer{
			"read-token":  {vpscatalog.AuthScopeCatalogRead},
			"issue-token": {vpscatalog.AuthScopeArtifactIssue},
		},
	})
}

func testClientVPSCatalogSnapshot(now time.Time) vpscatalog.CatalogSnapshot {
	evidenceExpires := now.Add(5 * time.Minute)
	return vpscatalog.CatalogSnapshot{
		Version:     vpscatalog.SchemaVersion,
		GeneratedAt: now,
		ExpiresAt:   now.Add(10 * time.Minute),
		Issuer:      "vk-turn-proxy-go",
		Audience:    "relay-client",
		EndpointID:  "vps-main",
		Generation:  2,
		Sources: []vpscatalog.ProviderSource{{
			ID:           "managed-turn",
			ProviderID:   "generic-turn",
			DisplayName:  "Managed TURN",
			SourceFamily: "managed_turn",
			Health: vpscatalog.Health{
				Status:    vpscatalog.HealthStatusHealthy,
				ExpiresAt: &evidenceExpires,
			},
			Evidence: []vpscatalog.Evidence{{
				Kind:      "synthetic_probe",
				Status:    vpscatalog.EvidenceStatusFresh,
				ExpiresAt: &evidenceExpires,
			}},
			ArtifactOffers: []vpscatalog.ArtifactOffer{{
				ID:                     "turn-handoff",
				Family:                 string(ArtifactFamilyGenericTURN),
				AccessMethods:          []string{string(RuntimeAccessMethodTURNCredentials)},
				Actions:                []string{string(ArtifactActionStartOnThisDevice)},
				RemoteEndpointFamily:   string(RuntimeRemoteEndpointFamilyTURNServer),
				RemoteEndpointRole:     string(RuntimeRemoteEndpointRoleWireGuardRawDatagram),
				CompatibleProfileKinds: []string{string(TransportProfileKindWireGuardNativeV1)},
				MaxTTLSeconds:          60,
				Health: vpscatalog.Health{
					Status:    vpscatalog.HealthStatusHealthy,
					ExpiresAt: &evidenceExpires,
				},
				Evidence: []vpscatalog.Evidence{{
					Kind:      "remote_ingress_probe",
					Status:    vpscatalog.EvidenceStatusFresh,
					ExpiresAt: &evidenceExpires,
				}},
				Redaction: vpscatalog.DefaultRedactionPolicy(),
			}},
		}},
	}
}

func testClientVPSArtifactIssueResponse(
	now time.Time,
	source vpscatalog.ProviderSource,
	offer vpscatalog.ArtifactOffer,
	evidenceStatus vpscatalog.EvidenceStatus,
) vpscatalog.ArtifactIssueResponse {
	expiresAt := now.Add(time.Minute)
	evidenceExpires := now.Add(5 * time.Minute)
	evidence := []vpscatalog.Evidence{{
		Kind:      "remote_ingress_probe",
		Status:    evidenceStatus,
		ExpiresAt: &evidenceExpires,
	}}
	return vpscatalog.ArtifactIssueResponse{
		OperationID: "op-missing-evidence",
		IssuedAt:    now,
		ExpiresAt:   expiresAt,
		Source: vpscatalog.SourceReference{
			EndpointID: "vps-main",
			Issuer:     "vk-turn-proxy-go",
			Audience:   "relay-client",
			Generation: 2,
			ProviderID: source.ProviderID,
			SourceID:   source.ID,
		},
		Artifact: vpscatalog.ArtifactReference{
			ID:                     "artifact-missing-evidence",
			SourceID:               source.ID,
			OfferID:                offer.ID,
			Family:                 offer.Family,
			AccessMethods:          append([]string(nil), offer.AccessMethods...),
			Actions:                append([]string(nil), offer.Actions...),
			RemoteEndpointFamily:   offer.RemoteEndpointFamily,
			RemoteEndpointRole:     offer.RemoteEndpointRole,
			CompatibleProfileKinds: append([]string(nil), offer.CompatibleProfileKinds...),
			Health: vpscatalog.Health{
				Status:    vpscatalog.HealthStatusHealthy,
				ExpiresAt: &evidenceExpires,
			},
			Evidence:  evidence,
			ExpiresAt: expiresAt,
		},
		Redaction: vpscatalog.DefaultRedactionPolicy(),
	}
}

type mutableHTTPHandler struct {
	mu      sync.RWMutex
	handler http.Handler
}

func (h *mutableHTTPHandler) set(handler http.Handler) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.handler = handler
}

func (h *mutableHTTPHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	h.mu.RLock()
	handler := h.handler
	h.mu.RUnlock()
	if handler == nil {
		http.NotFound(w, r)
		return
	}
	handler.ServeHTTP(w, r)
}
