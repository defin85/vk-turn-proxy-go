package clientcontrol

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestProviderTransportCompatibilityCapabilityAdvertised(t *testing.T) {
	host := New()

	info := host.Info()
	if !testContainsCapability(info.Capabilities, CapabilityProviderTransportCompat) {
		t.Fatalf("capabilities = %v, want %s", info.Capabilities, CapabilityProviderTransportCompat)
	}
	if info.ProviderTransportCompatibility == nil {
		t.Fatal("provider_transport_compatibility = nil, want capability metadata")
	}
	if info.ProviderTransportCompatibility.CandidateEndpoint != "/v1/provider-transport-compatibility/candidates" {
		t.Fatalf("candidate endpoint = %q", info.ProviderTransportCompatibility.CandidateEndpoint)
	}
	if !testContainsCompatibilityStatus(
		info.ProviderTransportCompatibility.Statuses,
		ProviderTransportCompatibilityStatusStartable,
	) {
		t.Fatalf("compatibility statuses = %+v, want startable", info.ProviderTransportCompatibility.Statuses)
	}
}

func TestProviderTransportCompatibilityStartableGenericTURNWireGuard(t *testing.T) {
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil)
	profile, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("compat-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	descriptor := testStrictWireGuardTurnDescriptor()

	response := host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
		TransportProfile: &TransportProfileReference{
			ProfileID: profile.ID,
			Kind:      profile.Kind,
		},
	})

	candidate := onlyCompatibilityCandidate(t, response)
	if candidate.Status != ProviderTransportCompatibilityStatusStartable || !candidate.Startable {
		t.Fatalf("candidate status = %+v, want startable", candidate)
	}
	if candidate.Source == nil || candidate.Source.ResolutionID != resolved.ID || candidate.Source.ProviderID != "generic-turn" {
		t.Fatalf("candidate source = %+v, want provider/resolution refs", candidate.Source)
	}
	if candidate.Artifact == nil || candidate.Artifact.Family != ArtifactFamilyGenericTURN {
		t.Fatalf("candidate artifact = %+v, want generic_turn", candidate.Artifact)
	}
	if candidate.SelectedTransportProfile == nil || candidate.SelectedTransportProfile.ProfileID != profile.ID {
		t.Fatalf("selected transport profile = %+v, want %s", candidate.SelectedTransportProfile, profile.ID)
	}

	body, err := json.Marshal(response)
	if err != nil {
		t.Fatalf("Marshal(response) error = %v", err)
	}
	if strings.Contains(string(body), "compat-client-key") || strings.Contains(string(body), "turn-pass") {
		t.Fatalf("compatibility response leaked secret material: %s", body)
	}
}

func TestProviderTransportCompatibilityReportsProfileFailures(t *testing.T) {
	tests := []struct {
		name       string
		configure  func(*testing.T, *Host) *TransportProfileReference
		wantStatus ProviderTransportCompatibilityStatus
		wantReason ProviderTransportCompatibilityReasonCode
	}{
		{
			name: "missing profile",
			configure: func(*testing.T, *Host) *TransportProfileReference {
				return nil
			},
			wantStatus: ProviderTransportCompatibilityStatusSetupNeeded,
			wantReason: ProviderTransportCompatibilityReasonTransportProfileRequired,
		},
		{
			name: "incompatible profile kind",
			configure: func(t *testing.T, host *Host) *TransportProfileReference {
				t.Helper()
				now := host.now().UTC()
				host.mu.Lock()
				host.transportProfiles["future-profile"] = managedTransportProfile{
					status: TransportProfileStatus{
						ID:      "future-profile",
						Kind:    TransportProfileKind("future_native_v1"),
						Version: "1",
						Validation: TransportProfileValidationStatus{
							State: TransportProfileValidationStateValid,
						},
						Compatibility: TransportProfileCompatibilityStatus{
							State: TransportProfileCompatibilityStateCompatible,
						},
						SecretMaterialRef: TransportProfileSecretMaterialRef{
							Kind: TransportProfileMaterialSourceStructured,
							Ref:  "host-owned:future-profile",
						},
						ImportedAt: now,
						UpdatedAt:  now,
					},
				}
				host.mu.Unlock()
				return &TransportProfileReference{
					ProfileID: "future-profile",
					Kind:      TransportProfileKind("future_native_v1"),
				}
			},
			wantStatus: ProviderTransportCompatibilityStatusUnsupported,
			wantReason: ProviderTransportCompatibilityReasonTransportProfileIncompatibleKind,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil)
			descriptor := testStrictWireGuardTurnDescriptor()
			ref := tt.configure(t, host)

			response := host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
				ResolutionID:     resolved.ID,
				ExecutionPlan:    &descriptor.Plan,
				TransportProfile: ref,
			})

			candidate := onlyCompatibilityCandidate(t, response)
			if candidate.Status != tt.wantStatus {
				t.Fatalf("candidate status = %q, want %q: %+v", candidate.Status, tt.wantStatus, candidate)
			}
			if candidate.FailingAxis != ProviderTransportCompatibilityAxisTransportProfile {
				t.Fatalf("failing axis = %q, want transport_profile", candidate.FailingAxis)
			}
			if candidate.ReasonCode != tt.wantReason {
				t.Fatalf("reason = %q, want %q", candidate.ReasonCode, tt.wantReason)
			}
			if candidate.Startable {
				t.Fatalf("candidate startable = true, want false: %+v", candidate)
			}
		})
	}
}

func TestProviderTransportCompatibilityReportsStaleProviderArtifact(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, &now)
	now = now.Add(2 * time.Minute)
	descriptor := testStrictWireGuardTurnDescriptor()

	response := host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
	})

	candidate := onlyCompatibilityCandidate(t, response)
	if candidate.Status != ProviderTransportCompatibilityStatusStale {
		t.Fatalf("candidate status = %q, want stale: %+v", candidate.Status, candidate)
	}
	if candidate.FailingAxis != ProviderTransportCompatibilityAxisProviderArtifact {
		t.Fatalf("failing axis = %q, want provider_artifact", candidate.FailingAxis)
	}
	if candidate.ReasonCode != ProviderTransportCompatibilityReasonProviderArtifactStale {
		t.Fatalf("reason = %q, want provider_artifact_stale", candidate.ReasonCode)
	}
}

func TestProviderTransportCompatibilityReportsUnsupportedAndEvidenceStates(t *testing.T) {
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil)
	unsupportedPlan := RuntimeExecutionPlan{
		AccessMethod:  RuntimeAccessMethodWebRTCCallAttach,
		CarrierFamily: RuntimeCarrierFamilyWebRTCDataChannel,
		EngineFamily:  RuntimeEngineFamilyProxyCoreAdapter,
	}

	response := host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  resolved.ID,
		ExecutionPlan: &unsupportedPlan,
	})
	candidate := onlyCompatibilityCandidate(t, response)
	if candidate.Status != ProviderTransportCompatibilityStatusUnsupported ||
		candidate.ReasonCode != ProviderTransportCompatibilityReasonRuntimePlanUnsupported {
		t.Fatalf("unsupported candidate = %+v", candidate)
	}

	source := &ProviderTransportSourceReference{ProviderID: "generic-turn", ResolutionID: resolved.ID}
	artifact := &ProviderTransportArtifactReference{
		ProviderID:    "generic-turn",
		ResolutionID:  resolved.ID,
		Family:        ArtifactFamilyGenericTURN,
		AccessMethods: []RuntimeAccessMethod{RuntimeAccessMethodTURNCredentials},
	}
	degraded := host.providerTransportCompatibilityCandidateForDescriptorLocked(
		ProviderTransportCompatibilityRequest{},
		source,
		artifact,
		RuntimeExecutionPlanDescriptor{
			Plan: RuntimeExecutionPlan{
				AccessMethod:  RuntimeAccessMethodTURNCredentials,
				CarrierFamily: RuntimeCarrierFamilyTURNDTLSOverlay,
				EngineFamily:  RuntimeEngineFamilyCustomPacketOverlay,
			},
			SupportState:         RuntimeExecutionPlanSupportStateExperimental,
			RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
		},
	)
	if degraded.Status != ProviderTransportCompatibilityStatusDegraded ||
		degraded.FailingAxis != ProviderTransportCompatibilityAxisDegradedPolicy {
		t.Fatalf("degraded candidate = %+v", degraded)
	}

	missingEvidence := host.providerTransportCompatibilityCandidateForDescriptorLocked(
		ProviderTransportCompatibilityRequest{RequireEvidence: true},
		source,
		artifact,
		RuntimeExecutionPlanDescriptor{
			Plan: RuntimeExecutionPlan{
				AccessMethod:  RuntimeAccessMethodTURNCredentials,
				CarrierFamily: RuntimeCarrierFamilyTURNDTLSOverlay,
				EngineFamily:  RuntimeEngineFamilyCustomPacketOverlay,
			},
			SupportState:         RuntimeExecutionPlanSupportStateSupported,
			RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay,
		},
	)
	if missingEvidence.Status != ProviderTransportCompatibilityStatusMissingEvidence ||
		missingEvidence.FailingAxis != ProviderTransportCompatibilityAxisEvidence {
		t.Fatalf("missing-evidence candidate = %+v", missingEvidence)
	}
}

func TestProviderTransportCompatibilityUnknownStatusOrAxisIsNonStartable(t *testing.T) {
	if ProviderTransportCompatibilityCandidateStartable(ProviderTransportCompatibilityCandidate{
		Status: ProviderTransportCompatibilityStatus("future_ready"),
	}) {
		t.Fatal("future status was treated as startable")
	}
	if ProviderTransportCompatibilityCandidateStartable(ProviderTransportCompatibilityCandidate{
		Status:      ProviderTransportCompatibilityStatusStartable,
		FailingAxis: ProviderTransportCompatibilityFailingAxis("future_axis"),
	}) {
		t.Fatal("future failing axis was treated as startable")
	}
}

func TestProviderTransportCompatibilityDoesNotImplicitlySelectCompatibleProfile(t *testing.T) {
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil)
	profile, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("unselected-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	host.mu.Lock()
	host.transportProfileDefaults = make(map[string]string)
	host.refreshTransportProfileStatusLocked(profile.ID)
	host.mu.Unlock()
	descriptor := testStrictWireGuardTurnDescriptor()

	response := host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
	})

	candidate := onlyCompatibilityCandidate(t, response)
	if candidate.Status != ProviderTransportCompatibilityStatusSetupNeeded {
		t.Fatalf("candidate status = %q, want setup_needed: %+v", candidate.Status, candidate)
	}
	if candidate.SelectedTransportProfile != nil {
		t.Fatalf("selected profile = %+v, want no implicit compatible profile", candidate.SelectedTransportProfile)
	}
	if candidate.ReasonCode != ProviderTransportCompatibilityReasonTransportProfileUnselected {
		t.Fatalf("reason = %q, want transport_profile_unselected", candidate.ReasonCode)
	}
}

func TestProviderTransportCompatibilityStartupRequiresExplicitProfileRef(t *testing.T) {
	starterCalls := 0
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil,
		WithPlatformTunnelStarter(func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			starterCalls++
			return PlatformTunnelStartResult{Mode: PlatformTunnelModeAndroidVPNService, Ready: true}, nil
		}),
	)
	if _, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("default-client-key")); err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	descriptor := testStrictWireGuardTurnDescriptor()

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode:          PlatformTunnelModeAndroidVPNService,
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
		RuntimeDefaults: &RuntimeDefaults{
			ListenAddr: reserveUDPAddr(t),
			PeerAddr:   "127.0.0.1:56000",
		},
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.ProviderTransportCompatibility == nil {
		t.Fatalf("startup result = %+v, want typed compatibility failure", result)
	}
	if result.ProviderTransportCompatibility.ReasonCode != ProviderTransportCompatibilityReasonTransportProfileRequired {
		t.Fatalf("compatibility failure = %+v, want explicit profile requirement", result.ProviderTransportCompatibility)
	}
	if result.Stage != PlatformTunnelStartupStageProfileValidate ||
		result.MissingPrerequisite != PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("startup result = %+v, want profile validation failure", result)
	}
	if starterCalls != 0 {
		t.Fatalf("starter calls = %d, want no native startup", starterCalls)
	}
}

func TestProviderTransportCompatibilityStartupRevalidatesStaleProfile(t *testing.T) {
	starterCalls := 0
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil,
		WithPlatformTunnelStarter(func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			starterCalls++
			return PlatformTunnelStartResult{Mode: PlatformTunnelModeAndroidVPNService, Ready: true}, nil
		}),
	)
	profile, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("stale-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	descriptor := testStrictWireGuardTurnDescriptor()
	startable := onlyCompatibilityCandidate(t, host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
		TransportProfile: &TransportProfileReference{
			ProfileID: profile.ID,
			Kind:      profile.Kind,
		},
	}))
	if !startable.Startable {
		t.Fatalf("candidate = %+v, want startable before stale mutation", startable)
	}
	if err := host.ForgetTransportProfile(profile.ID); err != nil {
		t.Fatalf("ForgetTransportProfile() error = %v", err)
	}

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode:          PlatformTunnelModeAndroidVPNService,
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
		TransportProfile: &TransportProfileReference{
			ProfileID: profile.ID,
			Kind:      profile.Kind,
		},
		ProviderTransportCompatibility: &ProviderTransportCompatibilityStartupReference{
			CandidateID: startable.ID,
			Source:      startable.Source,
			Artifact:    startable.Artifact,
		},
		RuntimeDefaults: &RuntimeDefaults{
			ListenAddr: reserveUDPAddr(t),
			PeerAddr:   "127.0.0.1:56000",
		},
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.ProviderTransportCompatibility == nil ||
		result.ProviderTransportCompatibility.Status != ProviderTransportCompatibilityStatusStale ||
		result.ProviderTransportCompatibility.ReasonCode != ProviderTransportCompatibilityReasonTransportProfileStale {
		t.Fatalf("startup compatibility failure = %+v, want stale profile", result.ProviderTransportCompatibility)
	}
	if starterCalls != 0 {
		t.Fatalf("starter calls = %d, want no native startup after stale candidate", starterCalls)
	}
}

func TestProviderTransportCompatibilityStartupRevalidatesExactArtifactReference(t *testing.T) {
	starterCalls := 0
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil,
		WithPlatformTunnelStarter(func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			starterCalls++
			return PlatformTunnelStartResult{Mode: PlatformTunnelModeAndroidVPNService, Ready: true}, nil
		}),
	)
	profile, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("exact-artifact-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	descriptor := testStrictWireGuardTurnDescriptor()
	startable := onlyCompatibilityCandidate(t, host.ProviderTransportCompatibilityCandidates(ProviderTransportCompatibilityRequest{
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
		TransportProfile: &TransportProfileReference{
			ProfileID: profile.ID,
			Kind:      profile.Kind,
		},
	}))
	if !startable.Startable {
		t.Fatalf("candidate = %+v, want startable before artifact mismatch", startable)
	}
	staleArtifact := cloneProviderTransportArtifactReference(startable.Artifact)
	staleArtifact.Family = ArtifactFamily("future_turn")

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode:          PlatformTunnelModeAndroidVPNService,
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
		TransportProfile: &TransportProfileReference{
			ProfileID: profile.ID,
			Kind:      profile.Kind,
		},
		ProviderTransportCompatibility: &ProviderTransportCompatibilityStartupReference{
			CandidateID: startable.ID,
			Source:      startable.Source,
			Artifact:    staleArtifact,
		},
		RuntimeDefaults: &RuntimeDefaults{
			ListenAddr: reserveUDPAddr(t),
			PeerAddr:   "127.0.0.1:56000",
		},
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.ProviderTransportCompatibility == nil ||
		result.ProviderTransportCompatibility.Status != ProviderTransportCompatibilityStatusStale ||
		result.ProviderTransportCompatibility.FailingAxis != ProviderTransportCompatibilityAxisProviderArtifact ||
		result.ProviderTransportCompatibility.ReasonCode != ProviderTransportCompatibilityReasonProviderArtifactStale {
		t.Fatalf("startup compatibility failure = %+v, want stale artifact", result.ProviderTransportCompatibility)
	}
	if starterCalls != 0 {
		t.Fatalf("starter calls = %d, want no native startup after artifact mismatch", starterCalls)
	}
}

func TestProviderTransportCompatibilityHTTPReturnsCandidates(t *testing.T) {
	host, resolved := providerTransportCompatibilityHostWithResolvedTURN(t, nil)
	descriptor := testStrictWireGuardTurnDescriptor()
	server := httptest.NewServer(Handler(host))
	t.Cleanup(server.Close)

	body, err := json.Marshal(ProviderTransportCompatibilityRequest{
		ResolutionID:  resolved.ID,
		ExecutionPlan: &descriptor.Plan,
	})
	if err != nil {
		t.Fatalf("Marshal(request) error = %v", err)
	}
	resp, err := http.Post(
		server.URL+"/v1/provider-transport-compatibility/candidates",
		"application/json",
		bytes.NewReader(body),
	)
	if err != nil {
		t.Fatalf("POST compatibility candidates error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST compatibility candidates status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var response ProviderTransportCompatibilityResponse
	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		t.Fatalf("decode compatibility response: %v", err)
	}
	if len(response.Candidates) != 1 {
		t.Fatalf("candidates len = %d, want 1", len(response.Candidates))
	}
}

func providerTransportCompatibilityHostWithResolvedTURN(
	t *testing.T,
	now *time.Time,
	extraOpts ...Option,
) (*Host, Resolution) {
	t.Helper()
	opts := []Option{
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
		withRegistry(provider.NewRegistry(fakeAdapter{
			name: "generic-turn",
			resolve: func(context.Context, string) (provider.Resolution, error) {
				return provider.Resolution{
					Credentials: provider.Credentials{
						Username: "turn-user",
						Password: "turn-pass",
						Address:  "turn.example.test:3478",
						TTL:      time.Minute,
					},
					Metadata: map[string]string{
						"provider":          "generic-turn",
						"resolution_method": "test_static",
					},
				}, nil
			},
		})),
	}
	if now != nil {
		opts = append(opts, withNow(func() time.Time { return *now }))
	}
	opts = append(opts, extraOpts...)
	host := New(opts...)
	resolutionState, err := host.StartResolution(context.Background(), StartResolutionRequest{
		Provider: "generic-turn",
		Input: &ProviderInputEnvelope{
			Kind: ProviderInputKindLink,
			Link: "turn://turn-user:turn-pass@turn.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}
	return host, waitForResolutionState(t, host, resolutionState.ID, ResolutionStateResolved)
}

func onlyCompatibilityCandidate(
	t *testing.T,
	response ProviderTransportCompatibilityResponse,
) ProviderTransportCompatibilityCandidate {
	t.Helper()
	if len(response.Candidates) != 1 {
		t.Fatalf("candidates len = %d, want 1: %+v", len(response.Candidates), response.Candidates)
	}
	return response.Candidates[0]
}

func testContainsCompatibilityStatus(
	statuses []ProviderTransportCompatibilityStatus,
	want ProviderTransportCompatibilityStatus,
) bool {
	for _, status := range statuses {
		if status == want {
			return true
		}
	}
	return false
}
