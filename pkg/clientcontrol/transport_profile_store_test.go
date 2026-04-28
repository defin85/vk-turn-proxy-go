package clientcontrol

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestTransportProfileStoreNegotiatesAndRedactsWireGuardProfile(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)

	info := host.Info()
	if !testContainsCapability(info.Capabilities, CapabilityVPNTransportProfileStore) {
		t.Fatalf("capabilities = %v, want %s", info.Capabilities, CapabilityVPNTransportProfileStore)
	}
	if info.TransportProfileStore == nil {
		t.Fatal("transport_profile_store = nil, want capability metadata")
	}
	if len(info.TransportProfileStore.ImportAdapters) != 1 ||
		info.TransportProfileStore.ImportAdapters[0].ID != TransportProfileImportAdapterWireGuardConf {
		t.Fatalf("import adapters = %+v, want wireguard_conf", info.TransportProfileStore.ImportAdapters)
	}
	if info.PlatformTunnels[0].ExecutionPlans[0].SupportState != RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf("support_state before import = %q, want unavailable", info.PlatformTunnels[0].ExecutionPlans[0].SupportState)
	}
	if got := info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile.MissingKind; got != TransportProfileKindWireGuardNativeV1 {
		t.Fatalf("missing_kind before import = %q, want %q", got, TransportProfileKindWireGuardNativeV1)
	}

	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("secret-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	if status.Kind != TransportProfileKindWireGuardNativeV1 {
		t.Fatalf("profile kind = %q, want %q", status.Kind, TransportProfileKindWireGuardNativeV1)
	}
	if status.SecretMaterialRef.Ref == "" || strings.Contains(status.SecretMaterialRef.Ref, "android-vpn-service.conf") {
		t.Fatalf("secret material ref = %+v, want opaque host-owned ref", status.SecretMaterialRef)
	}

	profiles, err := host.TransportProfiles()
	if err != nil {
		t.Fatalf("TransportProfiles() error = %v", err)
	}
	body, err := json.Marshal(profiles)
	if err != nil {
		t.Fatalf("Marshal(TransportProfiles) error = %v", err)
	}
	if strings.Contains(string(body), "secret-client-key") {
		t.Fatalf("ordinary profile read leaked secret material: %s", body)
	}
	if strings.Contains(string(body), "android-vpn-service.conf") {
		t.Fatalf("ordinary profile read leaked app-private path: %s", body)
	}

	info = host.Info()
	if info.PlatformTunnels[0].ExecutionPlans[0].SupportState != RuntimeExecutionPlanSupportStateSupported {
		t.Fatalf("support_state after import = %q, want supported", info.PlatformTunnels[0].ExecutionPlans[0].SupportState)
	}
	ref := info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile.SelectedProfile
	if ref == nil || ref.ProfileID != status.ID {
		t.Fatalf("selected profile ref = %+v, want %s", ref, status.ID)
	}
}

func TestPlatformTunnelStartupFailsProfileValidateBeforeStarterWhenMissingProfile(t *testing.T) {
	starterCalls := 0
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
		WithPlatformTunnelStarter(func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			starterCalls++
			return PlatformTunnelStartResult{}, nil
		}),
	)

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.Stage != PlatformTunnelStartupStageProfileValidate {
		t.Fatalf("startup stage = %q, want %q", result.Stage, PlatformTunnelStartupStageProfileValidate)
	}
	if result.MissingPrerequisite != PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("missing_prerequisite = %q, want %q", result.MissingPrerequisite, PlatformTunnelPrerequisiteTransportProfile)
	}
	if starterCalls != 0 {
		t.Fatalf("starter calls = %d, want 0 before profile validation passes", starterCalls)
	}
}

func TestPlatformTunnelStartupPassesProfileReferenceToStarter(t *testing.T) {
	var captured PlatformTunnelStartRequest
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
		WithPlatformTunnelStarter(func(_ context.Context, req PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			captured = req
			return PlatformTunnelStartResult{
				Mode:                req.Mode,
				ExecutionPlan:       cloneRuntimeExecutionPlan(req.ExecutionPlan),
				TransportProfile:    cloneTransportProfileReference(req.TransportProfile),
				Ready:               false,
				Stage:               PlatformTunnelStartupStageHostBringup,
				MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
				UnderlayRoutePolicy: req.UnderlayRoutePolicy,
				Message:             "test host stops after receiving the profile ref",
			}, nil
		}),
	)
	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("secret-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if captured.TransportProfile == nil || captured.TransportProfile.ProfileID != status.ID {
		t.Fatalf("captured transport profile = %+v, want %s", captured.TransportProfile, status.ID)
	}
	if result.TransportProfile == nil || result.TransportProfile.ProfileID != status.ID {
		t.Fatalf("result transport profile = %+v, want %s", result.TransportProfile, status.ID)
	}
}

func TestTransportProfileStorePersistsRedactedProfileWithPrivateFilePermissions(t *testing.T) {
	storePath := filepath.Join(t.TempDir(), "no-backup", "vpn-transport-profiles", "store.json")
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStorePath(storePath),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("persisted-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}

	info, err := os.Stat(storePath)
	if err != nil {
		t.Fatalf("stat persisted store: %v", err)
	}
	if got := info.Mode().Perm(); got&0o077 != 0 {
		t.Fatalf("store file permissions = %o, want no group/other access", got)
	}
	dirInfo, err := os.Stat(filepath.Dir(storePath))
	if err != nil {
		t.Fatalf("stat persisted store dir: %v", err)
	}
	if got := dirInfo.Mode().Perm(); got&0o077 != 0 {
		t.Fatalf("store directory permissions = %o, want no group/other access", got)
	}

	var captured PlatformTunnelStartRequest
	restored := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStorePath(storePath),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
		WithPlatformTunnelStarter(func(_ context.Context, req PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			captured = req
			return PlatformTunnelStartResult{
				Mode:                req.Mode,
				ExecutionPlan:       cloneRuntimeExecutionPlan(req.ExecutionPlan),
				TransportProfile:    cloneTransportProfileReference(req.TransportProfile),
				Ready:               false,
				Stage:               PlatformTunnelStartupStageHostBringup,
				MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
				UnderlayRoutePolicy: req.UnderlayRoutePolicy,
				Message:             "test host stops after receiving the profile ref",
			}, nil
		}),
	)
	profiles, err := restored.TransportProfiles()
	if err != nil {
		t.Fatalf("restored TransportProfiles() error = %v", err)
	}
	if len(profiles) != 1 || profiles[0].ID != status.ID {
		t.Fatalf("restored profiles = %+v, want profile %s", profiles, status.ID)
	}
	body, err := json.Marshal(profiles)
	if err != nil {
		t.Fatalf("Marshal(restored profiles) error = %v", err)
	}
	if strings.Contains(string(body), "persisted-client-key") {
		t.Fatalf("restored ordinary profile read leaked private key: %s", body)
	}
	if strings.Contains(string(body), storePath) {
		t.Fatalf("restored ordinary profile read leaked storage path: %s", body)
	}

	result, err := restored.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.Stage != PlatformTunnelStartupStageHostBringup {
		t.Fatalf("StartPlatformTunnel() stage = %q, want %q", result.Stage, PlatformTunnelStartupStageHostBringup)
	}
	if captured.TransportProfile == nil || captured.TransportProfile.ProfileID != status.ID {
		t.Fatalf("captured transport profile = %+v, want %s", captured.TransportProfile, status.ID)
	}
}

func TestTransportProfileStoreReplaceForgetAndStaleReferenceFailClosed(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("first-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	replacement := testWireGuardTransportProfileImport("replacement-client-key")
	replacement.ReplaceProfileID = status.ID
	replaced, err := host.ImportTransportProfile(replacement)
	if err != nil {
		t.Fatalf("replacement ImportTransportProfile() error = %v", err)
	}
	if replaced.ID != status.ID {
		t.Fatalf("replacement id = %q, want %q", replaced.ID, status.ID)
	}

	lease, err := host.materializeWireGuardTurnLeaseFromTransportProfile(
		"resolution-1",
		testStrictWireGuardTurnDescriptor(),
		provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		RuntimeDefaults{},
		&TransportProfileReference{ProfileID: status.ID},
	)
	if err != nil {
		t.Fatalf("materializeWireGuardTurnLeaseFromTransportProfile() error = %v", err)
	}
	if lease.ClientPrivateKey != "replacement-client-key" {
		t.Fatalf("lease client_private_key = %q, want replacement-client-key", lease.ClientPrivateKey)
	}

	if err := host.ForgetTransportProfile(status.ID); err != nil {
		t.Fatalf("ForgetTransportProfile() error = %v", err)
	}
	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
		TransportProfile: &TransportProfileReference{
			ProfileID: status.ID,
			Kind:      TransportProfileKindWireGuardNativeV1,
		},
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.Stage != PlatformTunnelStartupStageProfileValidate {
		t.Fatalf("startup stage = %q, want %q", result.Stage, PlatformTunnelStartupStageProfileValidate)
	}
	if result.MissingPrerequisite != PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("missing_prerequisite = %q, want %q", result.MissingPrerequisite, PlatformTunnelPrerequisiteTransportProfile)
	}
	_, err = host.materializeWireGuardTurnLeaseFromTransportProfile(
		"resolution-1",
		testStrictWireGuardTurnDescriptor(),
		provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		RuntimeDefaults{},
		&TransportProfileReference{ProfileID: status.ID},
	)
	if !errors.Is(err, ErrTransportProfileNotFound) {
		t.Fatalf("materialize after forget error = %v, want ErrTransportProfileNotFound", err)
	}
}

func TestTransportProfileStoreLifecycleValidateAndSelectForStartup(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("select-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}

	host.mu.Lock()
	host.transportProfileDefaults = make(map[string]string)
	host.refreshTransportProfileStatusLocked(status.ID)
	host.mu.Unlock()

	validated, err := host.ValidateTransportProfile(status.ID)
	if err != nil {
		t.Fatalf("ValidateTransportProfile() error = %v", err)
	}
	if validated.Validation.State != TransportProfileValidationStateValid {
		t.Fatalf("validated state = %q, want %q", validated.Validation.State, TransportProfileValidationStateValid)
	}
	if len(validated.DefaultFor) != 0 {
		t.Fatalf("validated default_for = %+v, want none before select", validated.DefaultFor)
	}

	selected, err := host.SelectTransportProfileForStartup(status.ID, TransportProfileSelectForStartupRequest{
		Plan: testStrictWireGuardTurnDescriptor().Plan,
	})
	if err != nil {
		t.Fatalf("SelectTransportProfileForStartup() error = %v", err)
	}
	if len(selected.DefaultFor) != 1 {
		t.Fatalf("selected default_for = %+v, want one scoped binding", selected.DefaultFor)
	}
	if selected.DefaultFor[0].ProfileID != status.ID {
		t.Fatalf("default profile id = %q, want %q", selected.DefaultFor[0].ProfileID, status.ID)
	}

	info := host.Info()
	ref := info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile.DefaultProfile
	if ref == nil || ref.ProfileID != status.ID {
		t.Fatalf("host default profile ref = %+v, want %s", ref, status.ID)
	}
}

func TestTransportProfileStoreHTTPExposesValidateAndSelectLifecycleActions(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("http-lifecycle-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}

	host.mu.Lock()
	host.transportProfileDefaults = make(map[string]string)
	host.refreshTransportProfileStatusLocked(status.ID)
	host.mu.Unlock()

	server := httptest.NewServer(Handler(host))
	t.Cleanup(server.Close)

	resp, err := http.Post(server.URL+"/v1/transport-profiles/"+status.ID+"/validate", "application/json", nil)
	if err != nil {
		t.Fatalf("POST validate error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST validate status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var validated TransportProfileStatus
	if err := json.NewDecoder(resp.Body).Decode(&validated); err != nil {
		t.Fatalf("decode validated profile: %v", err)
	}
	if validated.ID != status.ID || validated.Validation.State != TransportProfileValidationStateValid {
		t.Fatalf("validated profile = %+v, want valid %s", validated, status.ID)
	}

	body, err := json.Marshal(TransportProfileSelectForStartupRequest{
		Plan: testStrictWireGuardTurnDescriptor().Plan,
	})
	if err != nil {
		t.Fatalf("Marshal(select request) error = %v", err)
	}
	resp, err = http.Post(server.URL+"/v1/transport-profiles/"+status.ID+"/select-for-startup", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST select-for-startup error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST select-for-startup status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var selected TransportProfileStatus
	if err := json.NewDecoder(resp.Body).Decode(&selected); err != nil {
		t.Fatalf("decode selected profile: %v", err)
	}
	if len(selected.DefaultFor) != 1 || selected.DefaultFor[0].ProfileID != status.ID {
		t.Fatalf("selected default_for = %+v, want scoped default for %s", selected.DefaultFor, status.ID)
	}
}

func TestTransportProfileStoreMaterializationDoesNotFallbackToLegacyMaterializer(t *testing.T) {
	legacyMaterializerCalls := 0
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
		WithWireGuardTurnMaterializer(func(context.Context, WireGuardTurnMaterializeRequest) (*WireGuardTurnExecutionLease, error) {
			legacyMaterializerCalls++
			return &WireGuardTurnExecutionLease{}, nil
		}),
	)

	_, err := host.materializeWireGuardTurnLease(
		context.Background(),
		"resolution-1",
		testStrictWireGuardTurnDescriptor(),
		provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		RuntimeDefaults{},
		nil,
	)
	if err == nil {
		t.Fatal("materializeWireGuardTurnLease() error = nil, want missing transport profile")
	}
	if legacyMaterializerCalls != 0 {
		t.Fatalf("legacy materializer calls = %d, want 0 when profile store is enabled", legacyMaterializerCalls)
	}
}

func supportedTestAndroidVPNCapability() PlatformTunnelCapability {
	return PlatformTunnelCapability{
		Mode:      PlatformTunnelModeAndroidVPNService,
		Available: true,
		SatisfiedPrerequisites: []PlatformTunnelPrerequisite{
			PlatformTunnelPrerequisiteRouteExclusion,
			PlatformTunnelPrerequisiteDNSBypass,
		},
		SupportedUnderlayRoutePolicies: []PlatformTunnelUnderlayRoutePolicy{
			PlatformTunnelUnderlayRoutePolicyStandard,
		},
	}
}

func testStrictWireGuardTurnDescriptor() RuntimeExecutionPlanDescriptor {
	return RuntimeExecutionPlanDescriptor{
		Plan: RuntimeExecutionPlan{
			AccessMethod:  RuntimeAccessMethodTURNCredentials,
			CarrierFamily: RuntimeCarrierFamilyTURNDatagram,
			EngineFamily:  RuntimeEngineFamilyWireGuardNative,
			HostAdapter:   RuntimeHostAdapterAndroidVPNService,
		},
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
	}
}

func testWireGuardTransportProfileImport(privateKey string) TransportProfileImportRequest {
	return TransportProfileImportRequest{
		Adapter:     TransportProfileImportAdapterWireGuardConf,
		Kind:        TransportProfileKindWireGuardNativeV1,
		DisplayName: "phone transport",
		Material: strings.Join([]string{
			"[Interface]",
			"PrivateKey = " + privateKey,
			"Address = 10.10.0.2/32",
			"DNS = 1.1.1.1",
			"",
			"[Peer]",
			"PublicKey = peer-public-key",
			"AllowedIPs = 0.0.0.0/0",
			"Endpoint = relay.example.test:51820",
			"",
		}, "\n"),
	}
}

func testContainsCapability(capabilities []Capability, want Capability) bool {
	for _, capability := range capabilities {
		if capability == want {
			return true
		}
	}
	return false
}
