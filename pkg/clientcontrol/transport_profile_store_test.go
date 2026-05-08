package clientcontrol

import (
	"bytes"
	"context"
	"encoding/base64"
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
	if info.TransportProfileStore.ImportAdapters[0].ProfileKind != TransportProfileKindWireGuardNativeV1 ||
		info.TransportProfileStore.ImportAdapters[0].MaterialAcquisitionMethod != TransportProfileMaterialAcquisitionMethodPlainText {
		t.Fatalf("import adapter descriptor = %+v, want kind-specific plain_text adapter", info.TransportProfileStore.ImportAdapters[0])
	}
	if len(info.TransportProfileStore.EditableKinds) != 1 {
		t.Fatalf("editable kinds = %+v, want wireguard_native_v1 schema", info.TransportProfileStore.EditableKinds)
	}
	if info.TransportProfileStore.PortableTransfer == nil {
		t.Fatal("portable_transfer = nil, want advertised portable transfer capability")
	}
	if info.TransportProfileStore.PortableTransfer.EnvelopeType != portableTransportProfileEnvelopeType ||
		info.TransportProfileStore.PortableTransfer.EnvelopeVersion != portableTransportProfileEnvelopeVersion {
		t.Fatalf("portable transfer capability = %+v, want portable transport-profile envelope metadata", info.TransportProfileStore.PortableTransfer)
	}
	if info.TransportProfileStore.PortableTransfer.QRMaxPayloadBytes != portableTransportProfileQRMaxPayloadBytes ||
		info.TransportProfileStore.PortableTransfer.QRMode != TransportProfilePortableTransferQRModeSinglePayload {
		t.Fatalf("portable transfer qr metadata = %+v, want bounded single-payload qr support", info.TransportProfileStore.PortableTransfer)
	}
	schema := info.TransportProfileStore.EditableKinds[0]
	if schema.Kind != TransportProfileKindWireGuardNativeV1 || schema.SchemaVersion == "" {
		t.Fatalf("editable schema = %+v, want versioned wireguard_native_v1 schema", schema)
	}
	if !testStructuredSchemaHasField(schema, TransportProfileStructuredFieldInterfacePrivateKey, true) {
		t.Fatalf("editable schema fields = %+v, want generated/preservable private-key field", schema.Fields)
	}
	if !testContainsLifecycleAction(info.TransportProfileStore.LifecycleActions, TransportProfileLifecycleActionCreateStructured) ||
		!testContainsLifecycleAction(info.TransportProfileStore.LifecycleActions, TransportProfileLifecycleActionValidateDraft) {
		t.Fatalf("lifecycle actions = %+v, want structured actions", info.TransportProfileStore.LifecycleActions)
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
	if !testContainsLifecycleAction(status.Actions, TransportProfileLifecycleActionExportPortable) {
		t.Fatalf("actions after import = %+v, want export_portable", status.Actions)
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

func TestCloneTransportProfileStoreCapabilityPreservesPortableTransferMetadata(t *testing.T) {
	original := &TransportProfileStoreCapability{
		SupportedKinds: []TransportProfileKind{
			TransportProfileKindWireGuardNativeV1,
		},
		PortableTransfer: &TransportProfilePortableTransferCapability{
			EnvelopeType:    "portable_transport_profile",
			EnvelopeVersion: 1,
			SupportedKinds: []TransportProfileKind{
				TransportProfileKindWireGuardNativeV1,
			},
			ExportPaths: []TransportProfilePortableTransferPath{
				TransportProfilePortableTransferPathTextPayload,
				TransportProfilePortableTransferPathQRPayload,
			},
			ImportPaths: []TransportProfilePortableTransferPath{
				TransportProfilePortableTransferPathFilePayload,
			},
			QRMaxPayloadBytes: 2048,
			QRMode:            TransportProfilePortableTransferQRModeSinglePayload,
		},
	}

	cloned := cloneTransportProfileStoreCapability(original)
	if cloned == nil || cloned.PortableTransfer == nil {
		t.Fatalf("clone = %+v, want portable transfer metadata", cloned)
	}
	if cloned.PortableTransfer == original.PortableTransfer {
		t.Fatal("portable transfer capability pointer was reused")
	}
	if cloned.PortableTransfer.EnvelopeType != "portable_transport_profile" {
		t.Fatalf("envelope_type = %q, want portable_transport_profile", cloned.PortableTransfer.EnvelopeType)
	}
	if len(cloned.PortableTransfer.ExportPaths) != 2 || cloned.PortableTransfer.ExportPaths[1] != TransportProfilePortableTransferPathQRPayload {
		t.Fatalf("export_paths = %+v, want text+qr payloads", cloned.PortableTransfer.ExportPaths)
	}
	if len(cloned.PortableTransfer.ImportPaths) != 1 || cloned.PortableTransfer.ImportPaths[0] != TransportProfilePortableTransferPathFilePayload {
		t.Fatalf("import_paths = %+v, want file payload", cloned.PortableTransfer.ImportPaths)
	}

	original.PortableTransfer.SupportedKinds[0] = TransportProfileKind("mutated_kind")
	original.PortableTransfer.ExportPaths[0] = TransportProfilePortableTransferPath("mutated_path")
	if cloned.PortableTransfer.SupportedKinds[0] != TransportProfileKindWireGuardNativeV1 {
		t.Fatalf("supported_kinds clone mutated = %+v, want independent copy", cloned.PortableTransfer.SupportedKinds)
	}
	if cloned.PortableTransfer.ExportPaths[0] != TransportProfilePortableTransferPathTextPayload {
		t.Fatalf("export_paths clone mutated = %+v, want independent copy", cloned.PortableTransfer.ExportPaths)
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

func TestPlatformTunnelStartupAddsProfileReferenceToResultWhenStarterOmitsIt(t *testing.T) {
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
				Ready:               false,
				Stage:               PlatformTunnelStartupStageHostBringup,
				MissingPrerequisite: PlatformTunnelPrerequisiteHostImplementation,
				UnderlayRoutePolicy: req.UnderlayRoutePolicy,
				Message:             "test host deliberately omits the selected profile ref",
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

func TestTransportProfileStoreDoesNotInferStartupProfileFromCompatibleRecords(t *testing.T) {
	starterCalls := 0
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
		WithPlatformTunnelStarter(func(_ context.Context, req PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			starterCalls++
			return PlatformTunnelStartResult{
				Mode:             req.Mode,
				ExecutionPlan:    cloneRuntimeExecutionPlan(req.ExecutionPlan),
				TransportProfile: cloneTransportProfileReference(req.TransportProfile),
				Ready:            true,
			}, nil
		}),
	)

	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImport("explicit-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}
	host.mu.Lock()
	host.transportProfileDefaults = make(map[string]string)
	host.refreshTransportProfileStatusLocked(status.ID)
	host.mu.Unlock()

	info := host.Info()
	transportProfile := info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile
	if transportProfile == nil {
		t.Fatal("transport profile prerequisite = nil, want setup-needed status")
	}
	if transportProfile.SelectedProfile != nil || transportProfile.DefaultProfile != nil {
		t.Fatalf("transport profile refs = selected %+v default %+v, want no implicit selection", transportProfile.SelectedProfile, transportProfile.DefaultProfile)
	}
	if info.PlatformTunnels[0].ExecutionPlans[0].SupportState != RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf("support_state without selected/default profile = %q, want unavailable", info.PlatformTunnels[0].ExecutionPlans[0].SupportState)
	}

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.Stage != PlatformTunnelStartupStageProfileValidate ||
		result.MissingPrerequisite != PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("startup result without selection = %+v, want profile validation failure", result)
	}
	if starterCalls != 0 {
		t.Fatalf("starter calls = %d, want no startup without explicit/default profile", starterCalls)
	}

	result, err = host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
		TransportProfile: &TransportProfileReference{
			ProfileID: status.ID,
			Kind:      status.Kind,
		},
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel(explicit profile) error = %v", err)
	}
	if result.Stage == PlatformTunnelStartupStageProfileValidate ||
		result.MissingPrerequisite == PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("startup result with explicit profile = %+v, want to pass profile validation", result)
	}
	if result.TransportProfile == nil || result.TransportProfile.ProfileID != status.ID {
		t.Fatalf("startup result profile = %+v, want %s", result.TransportProfile, status.ID)
	}
	if starterCalls != 1 {
		t.Fatalf("starter calls = %d, want one explicit startup", starterCalls)
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

func TestTransportProfileStoreNonWireGuardProfileDoesNotBecomeStartable(t *testing.T) {
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

	now := host.now().UTC()
	host.mu.Lock()
	host.transportProfiles["future-profile"] = managedTransportProfile{
		status: TransportProfileStatus{
			ID:          "future-profile",
			Kind:        TransportProfileKind("future_native_v1"),
			Version:     "v1",
			DisplayName: "Future native profile",
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
	host.refreshTransportProfileStatusLocked("future-profile")
	host.mu.Unlock()

	profiles, err := host.TransportProfiles()
	if err != nil {
		t.Fatalf("TransportProfiles() error = %v", err)
	}
	if len(profiles) != 1 || profiles[0].Compatibility.State != TransportProfileCompatibilityStateIncompatible {
		t.Fatalf("future profile status = %+v, want incompatible ordinary status", profiles)
	}

	info := host.Info()
	plan := info.PlatformTunnels[0].ExecutionPlans[0]
	if plan.SupportState != RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf("support_state with future profile = %q, want unavailable", plan.SupportState)
	}
	if plan.TransportProfile == nil || plan.TransportProfile.MissingKind != TransportProfileKindWireGuardNativeV1 {
		t.Fatalf("transport profile prerequisite = %+v, want missing wireguard_native_v1", plan.TransportProfile)
	}

	if _, err := host.SelectTransportProfileForStartup("future-profile", TransportProfileSelectForStartupRequest{
		Plan: testStrictWireGuardTurnDescriptor().Plan,
	}); !errors.Is(err, ErrTransportProfileIncompatible) {
		t.Fatalf("SelectTransportProfileForStartup(future) error = %v, want ErrTransportProfileIncompatible", err)
	}

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
		TransportProfile: &TransportProfileReference{
			ProfileID: "future-profile",
			Kind:      TransportProfileKind("future_native_v1"),
		},
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel(future profile) error = %v", err)
	}
	if result.Stage != PlatformTunnelStartupStageProfileValidate {
		t.Fatalf("startup stage = %q, want %q", result.Stage, PlatformTunnelStartupStageProfileValidate)
	}
	if result.MissingPrerequisite != PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("missing_prerequisite = %q, want %q", result.MissingPrerequisite, PlatformTunnelPrerequisiteTransportProfile)
	}
	if starterCalls != 0 {
		t.Fatalf("starter calls = %d, want 0 for unsupported profile kind", starterCalls)
	}
}

func TestTransportProfileStoreFutureRequiredKindHasNoWireGuardImportFallback(t *testing.T) {
	starterCalls := 0
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelStarter(func(context.Context, PlatformTunnelStartRequest) (PlatformTunnelStartResult, error) {
			starterCalls++
			return PlatformTunnelStartResult{}, nil
		}),
	)

	host.mu.Lock()
	host.platformTunnels = []PlatformTunnelCapability{{
		Mode:      PlatformTunnelModeAndroidVPNService,
		Available: true,
		ExecutionPlans: []RuntimeExecutionPlanDescriptor{{
			Plan:                          testStrictWireGuardTurnDescriptor().Plan,
			SupportState:                  RuntimeExecutionPlanSupportStateSupported,
			RemoteEndpointFamily:          RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:            RuntimeRemoteEndpointRoleWireGuardRawDatagram,
			RequiredTransportProfileKinds: []TransportProfileKind{TransportProfileKind("future_native_v1")},
		}},
	}}
	host.mu.Unlock()

	info := host.Info()
	transportProfile := info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile
	if transportProfile == nil {
		t.Fatal("transport profile prerequisite = nil, want future kind prerequisite")
	}
	if transportProfile.MissingKind != TransportProfileKind("future_native_v1") {
		t.Fatalf("missing_kind = %q, want future_native_v1", transportProfile.MissingKind)
	}
	if len(transportProfile.ImportAdapters) != 0 {
		t.Fatalf("import adapters = %+v, want no WireGuard fallback for future kind", transportProfile.ImportAdapters)
	}
	if info.PlatformTunnels[0].ExecutionPlans[0].SupportState != RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf("support_state = %q, want unavailable", info.PlatformTunnels[0].ExecutionPlans[0].SupportState)
	}

	result, err := host.StartPlatformTunnel(context.Background(), PlatformTunnelStartRequest{
		Mode: PlatformTunnelModeAndroidVPNService,
	})
	if err != nil {
		t.Fatalf("StartPlatformTunnel() error = %v", err)
	}
	if result.Stage != PlatformTunnelStartupStageProfileValidate ||
		result.MissingPrerequisite != PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("startup result = %+v, want profile validation failure", result)
	}
	if !strings.Contains(result.Message, "future_native_v1") {
		t.Fatalf("startup message = %q, want future kind requirement", result.Message)
	}
	if starterCalls != 0 {
		t.Fatalf("starter calls = %d, want 0 for future required kind", starterCalls)
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

func TestTransportProfilePortableExportPreviewConfirmRoundTrip(t *testing.T) {
	sourceHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	sourceStatus, err := sourceHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-source-private-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(source) error = %v", err)
	}

	exported, err := sourceHost.ExportTransportProfilePortable(sourceStatus.ID, TransportProfilePortableExportRequest{
		Passphrase: "transfer-passphrase",
	})
	if err != nil {
		t.Fatalf("ExportTransportProfilePortable() error = %v", err)
	}
	if exported.ProfileKind != TransportProfileKindWireGuardNativeV1 ||
		exported.DisplayName != sourceStatus.DisplayName ||
		exported.EncodedBytes <= 0 {
		t.Fatalf("exported portable result = %+v, want safe envelope metadata", exported)
	}
	body, err := json.Marshal(exported)
	if err != nil {
		t.Fatalf("Marshal(exported) error = %v", err)
	}
	if strings.Contains(string(body), "portable-source-private-key") ||
		strings.Contains(string(body), "relay.example.test:51820") {
		t.Fatalf("portable export response leaked secret material: %s", body)
	}

	var envelope map[string]any
	if err := json.Unmarshal([]byte(exported.Envelope), &envelope); err != nil {
		t.Fatalf("portable envelope json = %v", err)
	}
	if envelope["type"] != portableTransportProfileEnvelopeType ||
		int(envelope["version"].(float64)) != portableTransportProfileEnvelopeVersion {
		t.Fatalf("portable envelope cleartext metadata = %+v, want portable transport-profile identity", envelope)
	}
	if _, ok := envelope["display_name"]; ok {
		t.Fatalf("portable envelope cleartext leaked display_name: %+v", envelope)
	}
	if _, ok := envelope["wireguard_native_v1"]; ok {
		t.Fatalf("portable envelope cleartext leaked wireguard material: %+v", envelope)
	}

	destinationHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	preview, err := destinationHost.PreviewTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "transfer-passphrase",
	})
	if err != nil {
		t.Fatalf("PreviewTransportProfilePortableImport() error = %v", err)
	}
	if preview.Outcome != TransportProfilePortableTransferPreviewOutcomeImportable ||
		preview.ProfileKind != TransportProfileKindWireGuardNativeV1 ||
		preview.DisplayName != sourceStatus.DisplayName ||
		preview.ResolvedDisplayName != sourceStatus.DisplayName ||
		preview.Compatibility == nil ||
		preview.Compatibility.State != TransportProfileCompatibilityStateCompatible ||
		!preview.SelectionRequired {
		t.Fatalf("preview = %+v, want importable compatible preview", preview)
	}
	profiles, err := destinationHost.TransportProfiles()
	if err != nil {
		t.Fatalf("TransportProfiles(destination before confirm) error = %v", err)
	}
	if len(profiles) != 0 {
		t.Fatalf("profiles before confirm = %+v, want no persisted import side effects", profiles)
	}

	imported, err := destinationHost.ConfirmTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "transfer-passphrase",
	})
	if err != nil {
		t.Fatalf("ConfirmTransportProfilePortableImport() error = %v", err)
	}
	if imported.ID == sourceStatus.ID {
		t.Fatalf("imported id = %q, want fresh local id distinct from source %q", imported.ID, sourceStatus.ID)
	}
	if imported.SecretMaterialRef.Kind != TransportProfileMaterialSourcePortableTransfer {
		t.Fatalf("secret material source = %+v, want portable_transfer", imported.SecretMaterialRef)
	}
	if len(imported.DefaultFor) != 0 {
		t.Fatalf("imported default_for = %+v, want no implicit startup selection", imported.DefaultFor)
	}
	if !testContainsLifecycleAction(imported.Actions, TransportProfileLifecycleActionExportPortable) {
		t.Fatalf("imported actions = %+v, want export_portable on imported record", imported.Actions)
	}

	info := destinationHost.Info()
	if info.PlatformTunnels[0].ExecutionPlans[0].SupportState != RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf("support_state after portable import = %q, want unavailable until explicit selection", info.PlatformTunnels[0].ExecutionPlans[0].SupportState)
	}
	if info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile == nil ||
		info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile.SelectedProfile != nil ||
		info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile.DefaultProfile != nil {
		t.Fatalf("transport profile prerequisite after portable import = %+v, want setup-needed state", info.PlatformTunnels[0].ExecutionPlans[0].TransportProfile)
	}
}

func TestTransportProfilePortableImportPreviewBlocksWrongPassphrase(t *testing.T) {
	sourceHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	sourceStatus, err := sourceHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-wrong-pass-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(source) error = %v", err)
	}
	exported, err := sourceHost.ExportTransportProfilePortable(sourceStatus.ID, TransportProfilePortableExportRequest{
		Passphrase: "correct-passphrase",
	})
	if err != nil {
		t.Fatalf("ExportTransportProfilePortable() error = %v", err)
	}

	destinationHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	preview, err := destinationHost.PreviewTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "wrong-passphrase",
	})
	if err != nil {
		t.Fatalf("PreviewTransportProfilePortableImport(wrong passphrase) error = %v", err)
	}
	if preview.Outcome != TransportProfilePortableTransferPreviewOutcomeBlocked ||
		preview.BlockedReason != TransportProfilePortableTransferBlockedReasonWrongPassphrase {
		t.Fatalf("wrong-passphrase preview = %+v, want blocked/wrong_passphrase", preview)
	}
	profiles, err := destinationHost.TransportProfiles()
	if err != nil {
		t.Fatalf("TransportProfiles(destination) error = %v", err)
	}
	if len(profiles) != 0 {
		t.Fatalf("profiles after blocked preview = %+v, want no imported records", profiles)
	}
}

func TestTransportProfilePortableImportPreviewReturnsAlreadyPresentForExactDuplicate(t *testing.T) {
	sourceHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	sourceStatus, err := sourceHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-duplicate-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(source) error = %v", err)
	}
	exported, err := sourceHost.ExportTransportProfilePortable(sourceStatus.ID, TransportProfilePortableExportRequest{
		Passphrase: "duplicate-passphrase",
	})
	if err != nil {
		t.Fatalf("ExportTransportProfilePortable() error = %v", err)
	}

	destinationHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	existing, err := destinationHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-duplicate-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(destination existing) error = %v", err)
	}
	preview, err := destinationHost.PreviewTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "duplicate-passphrase",
	})
	if err != nil {
		t.Fatalf("PreviewTransportProfilePortableImport(duplicate) error = %v", err)
	}
	if preview.Outcome != TransportProfilePortableTransferPreviewOutcomeAlreadyPresent ||
		preview.DuplicateFingerprint == "" ||
		len(preview.ExistingProfiles) != 1 ||
		preview.ExistingProfiles[0].ProfileID != existing.ID ||
		preview.SelectionRequired {
		t.Fatalf("duplicate preview = %+v, want already_present pointing at existing selected record", preview)
	}

	_, err = destinationHost.ConfirmTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "duplicate-passphrase",
	})
	if err == nil {
		t.Fatal("ConfirmTransportProfilePortableImport(duplicate) error = nil, want no second identical record")
	}
	profiles, err := destinationHost.TransportProfiles()
	if err != nil {
		t.Fatalf("TransportProfiles(destination) error = %v", err)
	}
	if len(profiles) != 1 {
		t.Fatalf("profiles after duplicate confirm attempt = %+v, want one existing record", profiles)
	}
}

func TestTransportProfilePortableImportPreviewSuggestsResolvedDisplayNameForNameCollision(t *testing.T) {
	sourceHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	sourceStatus, err := sourceHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-name-collision-source-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(source) error = %v", err)
	}
	exported, err := sourceHost.ExportTransportProfilePortable(sourceStatus.ID, TransportProfilePortableExportRequest{
		Passphrase: "collision-passphrase",
	})
	if err != nil {
		t.Fatalf("ExportTransportProfilePortable() error = %v", err)
	}

	destinationHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	if _, err := destinationHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-name-collision-existing-key")); err != nil {
		t.Fatalf("ImportTransportProfile(destination existing) error = %v", err)
	}
	preview, err := destinationHost.PreviewTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "collision-passphrase",
	})
	if err != nil {
		t.Fatalf("PreviewTransportProfilePortableImport(name collision) error = %v", err)
	}
	if preview.Outcome != TransportProfilePortableTransferPreviewOutcomeImportable ||
		preview.ResolvedDisplayName != "phone transport (2)" ||
		len(preview.Warnings) != 1 ||
		preview.Warnings[0].Code != TransportProfilePortableTransferPreviewWarningDisplayNameConflict {
		t.Fatalf("name-collision preview = %+v, want importable warning with resolved local name", preview)
	}

	imported, err := destinationHost.ConfirmTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "collision-passphrase",
	})
	if err != nil {
		t.Fatalf("ConfirmTransportProfilePortableImport(name collision) error = %v", err)
	}
	if imported.DisplayName != "phone transport (2)" {
		t.Fatalf("imported display name = %q, want suggested resolved local name", imported.DisplayName)
	}
}

func TestTransportProfilePortableImportPreviewBlocksUnsupportedEnvelopeVersion(t *testing.T) {
	sourceHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	sourceStatus, err := sourceHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-version-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(source) error = %v", err)
	}
	exported, err := sourceHost.ExportTransportProfilePortable(sourceStatus.ID, TransportProfilePortableExportRequest{
		Passphrase: "version-passphrase",
	})
	if err != nil {
		t.Fatalf("ExportTransportProfilePortable() error = %v", err)
	}
	var envelope map[string]any
	if err := json.Unmarshal([]byte(exported.Envelope), &envelope); err != nil {
		t.Fatalf("Unmarshal(exported envelope) error = %v", err)
	}
	envelope["version"] = float64(99)
	mutated, err := json.Marshal(envelope)
	if err != nil {
		t.Fatalf("Marshal(mutated envelope) error = %v", err)
	}

	destinationHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	preview, err := destinationHost.PreviewTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   string(mutated),
		Passphrase: "version-passphrase",
	})
	if err != nil {
		t.Fatalf("PreviewTransportProfilePortableImport(unsupported version) error = %v", err)
	}
	if preview.Outcome != TransportProfilePortableTransferPreviewOutcomeBlocked ||
		preview.BlockedReason != TransportProfilePortableTransferBlockedReasonUnsupportedEnvelope {
		t.Fatalf("unsupported-version preview = %+v, want blocked/unsupported_envelope", preview)
	}
}

func TestTransportProfilePortableImportPreviewBlocksIncompatibleHost(t *testing.T) {
	sourceHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	sourceStatus, err := sourceHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-incompatible-host-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(source) error = %v", err)
	}
	exported, err := sourceHost.ExportTransportProfilePortable(sourceStatus.ID, TransportProfilePortableExportRequest{
		Passphrase: "host-passphrase",
	})
	if err != nil {
		t.Fatalf("ExportTransportProfilePortable() error = %v", err)
	}

	incompatibleCapability := supportedTestAndroidVPNCapability()
	incompatibleCapability.ExecutionPlans = []RuntimeExecutionPlanDescriptor{{
		Plan:                 testStrictWireGuardTurnDescriptor().Plan,
		SupportState:         RuntimeExecutionPlanSupportStateUnavailable,
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   RuntimeRemoteEndpointRoleWireGuardRawDatagram,
	}}
	destinationHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{incompatibleCapability}),
	)
	preview, err := destinationHost.PreviewTransportProfilePortableImport(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "host-passphrase",
	})
	if err != nil {
		t.Fatalf("PreviewTransportProfilePortableImport(incompatible host) error = %v", err)
	}
	if preview.Outcome != TransportProfilePortableTransferPreviewOutcomeBlocked ||
		preview.BlockedReason != TransportProfilePortableTransferBlockedReasonIncompatibleHost {
		t.Fatalf("incompatible-host preview = %+v, want blocked/incompatible_host", preview)
	}
}

func TestTransportProfileStoreHTTPExposesPortableTransferActions(t *testing.T) {
	sourceHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	sourceStatus, err := sourceHost.ImportTransportProfile(testWireGuardTransportProfileImport("portable-http-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile(source) error = %v", err)
	}
	sourceServer := httptest.NewServer(Handler(sourceHost))
	t.Cleanup(sourceServer.Close)

	destinationHost := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	destinationServer := httptest.NewServer(Handler(destinationHost))
	t.Cleanup(destinationServer.Close)

	exportBody, err := json.Marshal(TransportProfilePortableExportRequest{Passphrase: "http-transfer-passphrase"})
	if err != nil {
		t.Fatalf("Marshal(export request) error = %v", err)
	}
	resp, err := http.Post(
		sourceServer.URL+"/v1/transport-profiles/"+sourceStatus.ID+"/export-portable",
		"application/json",
		bytes.NewReader(exportBody),
	)
	if err != nil {
		t.Fatalf("POST export-portable error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST export-portable status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var exported TransportProfilePortableExportResult
	if err := json.NewDecoder(resp.Body).Decode(&exported); err != nil {
		t.Fatalf("decode exported result: %v", err)
	}

	importBody, err := json.Marshal(TransportProfilePortableImportRequest{
		Envelope:   exported.Envelope,
		Passphrase: "http-transfer-passphrase",
	})
	if err != nil {
		t.Fatalf("Marshal(import request) error = %v", err)
	}
	resp, err = http.Post(
		destinationServer.URL+"/v1/transport-profiles:preview-portable-import",
		"application/json",
		bytes.NewReader(importBody),
	)
	if err != nil {
		t.Fatalf("POST preview-portable-import error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST preview-portable-import status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var preview TransportProfilePortableTransferPreview
	if err := json.NewDecoder(resp.Body).Decode(&preview); err != nil {
		t.Fatalf("decode portable preview: %v", err)
	}
	if preview.Outcome != TransportProfilePortableTransferPreviewOutcomeImportable {
		t.Fatalf("preview = %+v, want importable", preview)
	}

	resp, err = http.Post(
		destinationServer.URL+"/v1/transport-profiles:confirm-portable-import",
		"application/json",
		bytes.NewReader(importBody),
	)
	if err != nil {
		t.Fatalf("POST confirm-portable-import error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST confirm-portable-import status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var imported TransportProfileStatus
	if err := json.NewDecoder(resp.Body).Decode(&imported); err != nil {
		t.Fatalf("decode imported profile: %v", err)
	}
	if imported.SecretMaterialRef.Kind != TransportProfileMaterialSourcePortableTransfer {
		t.Fatalf("imported profile = %+v, want portable_transfer source", imported)
	}
}

func TestStructuredTransportProfileCreateUpdateValidateAndMaterialize(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)

	invalidDraft := testStructuredWireGuardDraft()
	invalidDraft.InterfacePrivateKeyAction = TransportProfileSecretUpdateActionGenerateHost
	invalidDraft.InterfaceAddresses = []string{"not-a-prefix"}
	validation, err := host.ValidateStructuredTransportProfileDraft(TransportProfileStructuredValidationRequest{
		Draft: invalidDraft,
	})
	if err != nil {
		t.Fatalf("ValidateStructuredTransportProfileDraft() error = %v", err)
	}
	if validation.Valid || !testValidationHasField(validation, TransportProfileStructuredFieldInterfaceAddresses, "malformed") {
		t.Fatalf("invalid validation result = %+v, want malformed interface_addresses", validation)
	}

	createDraft := testStructuredWireGuardDraft()
	createDraft.InterfacePrivateKeyAction = TransportProfileSecretUpdateActionGenerateHost
	createDraft.PeerPresharedKey = testWireGuardStructuredKey(4)
	createDraft.PersistentKeepaliveSeconds = 17
	createResult, err := host.CreateStructuredTransportProfile(TransportProfileStructuredCreateRequest{
		Draft: createDraft,
	})
	if err != nil {
		t.Fatalf("CreateStructuredTransportProfile() error = %v", err)
	}
	status := createResult.Profile
	if len(createResult.GeneratedKeys) != 1 ||
		createResult.GeneratedKeys[0].Field != TransportProfileStructuredFieldInterfacePrivateKey ||
		createResult.GeneratedKeys[0].PublicKey == "" {
		t.Fatalf("generated keys = %+v, want safe public-key metadata", createResult.GeneratedKeys)
	}
	if status.SecretMaterialRef.Kind != TransportProfileMaterialSourceStructured {
		t.Fatalf("secret material source = %q, want %q", status.SecretMaterialRef.Kind, TransportProfileMaterialSourceStructured)
	}
	profiles, err := host.TransportProfiles()
	if err != nil {
		t.Fatalf("TransportProfiles() error = %v", err)
	}
	body, err := json.Marshal(profiles)
	if err != nil {
		t.Fatalf("Marshal(TransportProfiles) error = %v", err)
	}
	if strings.Contains(string(body), testWireGuardStructuredKey(4)) {
		t.Fatalf("ordinary profile read leaked structured preshared key: %s", body)
	}

	lease, err := host.materializeWireGuardTurnLeaseFromTransportProfile(
		"resolution-structured",
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
	initialPrivateKey := lease.ClientPrivateKey
	if initialPrivateKey == "" {
		t.Fatal("materialized client private key is empty, want host-generated key")
	}
	if lease.PresharedKey != testWireGuardStructuredKey(4) {
		t.Fatalf("lease preshared key = %q, want submitted key", lease.PresharedKey)
	}
	if lease.PersistentKeepaliveSeconds != 17 {
		t.Fatalf("lease persistent keepalive = %d, want 17", lease.PersistentKeepaliveSeconds)
	}

	updateDraft := testStructuredWireGuardDraft()
	updateDraft.InterfacePrivateKeyAction = TransportProfileSecretUpdateActionPreserveExisting
	updateDraft.PeerPresharedKeyAction = TransportProfileSecretUpdateActionPreserveExisting
	updateDraft.AllowedIPs = []string{"10.30.0.0/16"}
	updateDraft.Endpoint = "relay-two.example.test:51820"
	updateDraft.PersistentKeepaliveSeconds = 31
	updateResult, err := host.UpdateStructuredTransportProfile(status.ID, TransportProfileStructuredUpdateRequest{
		Draft: updateDraft,
	})
	if err != nil {
		t.Fatalf("UpdateStructuredTransportProfile() error = %v", err)
	}
	updated := updateResult.Profile
	if updated.ID != status.ID {
		t.Fatalf("updated profile id = %q, want %q", updated.ID, status.ID)
	}

	lease, err = host.materializeWireGuardTurnLeaseFromTransportProfile(
		"resolution-structured",
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
		t.Fatalf("materialize after update error = %v", err)
	}
	if lease.ClientPrivateKey != initialPrivateKey {
		t.Fatalf("private key after preserve = %q, want %q", lease.ClientPrivateKey, initialPrivateKey)
	}
	if len(lease.AllowedIPs) != 1 || lease.AllowedIPs[0] != "10.30.0.0/16" {
		t.Fatalf("lease allowed IPs after update = %+v, want 10.30.0.0/16", lease.AllowedIPs)
	}
	if lease.PersistentKeepaliveSeconds != 31 {
		t.Fatalf("lease persistent keepalive after update = %d, want 31", lease.PersistentKeepaliveSeconds)
	}

	badUpdate := updateDraft
	badUpdate.AllowedIPs = []string{"bad"}
	if _, err := host.UpdateStructuredTransportProfile(status.ID, TransportProfileStructuredUpdateRequest{
		Draft: badUpdate,
	}); !errors.Is(err, ErrTransportProfileInvalid) {
		t.Fatalf("invalid UpdateStructuredTransportProfile() error = %v, want ErrTransportProfileInvalid", err)
	}
	lease, err = host.materializeWireGuardTurnLeaseFromTransportProfile(
		"resolution-structured",
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
		t.Fatalf("materialize after invalid update error = %v", err)
	}
	if len(lease.AllowedIPs) != 1 || lease.AllowedIPs[0] != "10.30.0.0/16" {
		t.Fatalf("lease allowed IPs after rejected update = %+v, want previous value", lease.AllowedIPs)
	}
}

func TestStructuredTransportProfileAcceptsGenericDraftMaps(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)

	badDraft := testGenericStructuredWireGuardDraft()
	badDraft.Fields[TransportProfileStructuredFieldID("future_field")] = "unsupported"
	validation, err := host.ValidateStructuredTransportProfileDraft(TransportProfileStructuredValidationRequest{
		Draft: badDraft,
	})
	if err != nil {
		t.Fatalf("ValidateStructuredTransportProfileDraft() error = %v", err)
	}
	if validation.Valid || !testValidationHasField(validation, TransportProfileStructuredFieldID("future_field"), "unknown") {
		t.Fatalf("validation = %+v, want unknown future_field", validation)
	}

	createDraft := testGenericStructuredWireGuardDraft()
	createResult, err := host.CreateStructuredTransportProfile(TransportProfileStructuredCreateRequest{
		Draft: createDraft,
	})
	if err != nil {
		t.Fatalf("CreateStructuredTransportProfile(generic maps) error = %v", err)
	}
	if len(createResult.GeneratedKeys) != 1 ||
		createResult.GeneratedKeys[0].Field != TransportProfileStructuredFieldInterfacePrivateKey {
		t.Fatalf("generated keys = %+v, want private-key metadata", createResult.GeneratedKeys)
	}
	lease, err := host.materializeWireGuardTurnLeaseFromTransportProfile(
		"resolution-generic",
		host.Info().PlatformTunnels[0].ExecutionPlans[0],
		provider.Credentials{Address: "turn.example.test:3478", Username: "user", Password: "pass"},
		RuntimeDefaults{},
		&TransportProfileReference{ProfileID: createResult.Profile.ID},
	)
	if err != nil {
		t.Fatalf("materialize generic profile error = %v", err)
	}
	if lease.ClientAddresses[0] != "10.66.0.2/32" ||
		lease.PeerPublicKey != testWireGuardStructuredKey(2) ||
		lease.PersistentKeepaliveSeconds != 23 {
		t.Fatalf("lease from generic draft = %+v, want generic field material", lease)
	}
}

func TestTransportProfileStoreHTTPExposesStructuredActions(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	server := httptest.NewServer(Handler(host))
	t.Cleanup(server.Close)

	keyBody, err := json.Marshal(TransportProfileGenerateKeyRequest{
		Kind: TransportProfileKindWireGuardNativeV1,
	})
	if err != nil {
		t.Fatalf("Marshal(key request) error = %v", err)
	}
	resp, err := http.Post(server.URL+"/v1/transport-profiles:generate-key", "application/json", bytes.NewReader(keyBody))
	if err != nil {
		t.Fatalf("POST generate-key error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST generate-key status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var key TransportProfileGeneratedKey
	if err := json.NewDecoder(resp.Body).Decode(&key); err != nil {
		t.Fatalf("decode generated key: %v", err)
	}
	if key.PublicKey == "" || key.Fingerprint == "" {
		t.Fatalf("generated key = %+v, want safe public key metadata", key)
	}

	createDraft := testStructuredWireGuardDraft()
	createDraft.InterfacePrivateKeyAction = TransportProfileSecretUpdateActionGenerateHost
	createBody, err := json.Marshal(TransportProfileStructuredCreateRequest{Draft: createDraft})
	if err != nil {
		t.Fatalf("Marshal(create request) error = %v", err)
	}
	resp, err = http.Post(server.URL+"/v1/transport-profiles:structured", "application/json", bytes.NewReader(createBody))
	if err != nil {
		t.Fatalf("POST structured create error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST structured create status = %d, want %d", resp.StatusCode, http.StatusOK)
	}
	var createdResult TransportProfileStructuredSaveResult
	if err := json.NewDecoder(resp.Body).Decode(&createdResult); err != nil {
		t.Fatalf("decode created profile: %v", err)
	}
	created := createdResult.Profile
	if len(createdResult.GeneratedKeys) != 1 || createdResult.GeneratedKeys[0].PublicKey == "" {
		t.Fatalf("created generated keys = %+v, want public-key metadata", createdResult.GeneratedKeys)
	}

	updateDraft := testStructuredWireGuardDraft()
	updateDraft.InterfacePrivateKeyAction = TransportProfileSecretUpdateActionPreserveExisting
	updateDraft.AllowedIPs = []string{"10.40.0.0/16"}
	updateBody, err := json.Marshal(TransportProfileStructuredUpdateRequest{Draft: updateDraft})
	if err != nil {
		t.Fatalf("Marshal(update request) error = %v", err)
	}
	resp, err = http.Post(server.URL+"/v1/transport-profiles/"+created.ID+"/structured-update", "application/json", bytes.NewReader(updateBody))
	if err != nil {
		t.Fatalf("POST structured update error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST structured update status = %d, want %d", resp.StatusCode, http.StatusOK)
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

func TestTransportProfileStoreMaterializationRequiresExplicitRawIngressEndpoint(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	status, err := host.ImportTransportProfile(testWireGuardTransportProfileImportWithoutEndpoint("secret-client-key"))
	if err != nil {
		t.Fatalf("ImportTransportProfile() error = %v", err)
	}

	_, err = host.materializeWireGuardTurnLeaseFromTransportProfile(
		"resolution-1",
		testStrictWireGuardTurnDescriptor(),
		provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		RuntimeDefaults{PeerAddr: "dtls-only.example.test:56040"},
		&TransportProfileReference{ProfileID: status.ID},
	)
	if err == nil {
		t.Fatal("materializeWireGuardTurnLeaseFromTransportProfile() error = nil, want explicit raw ingress endpoint failure")
	}
	if !strings.Contains(err.Error(), "explicit raw WireGuard ingress endpoint") {
		t.Fatalf("materializeWireGuardTurnLeaseFromTransportProfile() error = %v, want raw-ingress endpoint detail", err)
	}
}

func TestWireGuardTurnMaterializationRejectsDTLSOnlyEndpointRole(t *testing.T) {
	host := New(
		WithBuildIdentity(BuildIdentity{Target: "android/embedded"}),
		WithVPNTransportProfileStore(),
		WithPlatformTunnelCapabilities([]PlatformTunnelCapability{supportedTestAndroidVPNCapability()}),
	)
	descriptor := testStrictWireGuardTurnDescriptor()
	descriptor.RemoteEndpointRole = RuntimeRemoteEndpointRoleTURNDTLSCustomOverlay

	_, err := host.materializeWireGuardTurnLease(
		context.Background(),
		"resolution-1",
		descriptor,
		provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
		},
		RuntimeDefaults{},
		nil,
	)
	if err == nil {
		t.Fatal("materializeWireGuardTurnLease() error = nil, want protocol mismatch failure")
	}
	if !strings.Contains(err.Error(), "remote_endpoint_role") {
		t.Fatalf("materializeWireGuardTurnLease() error = %v, want remote_endpoint_role detail", err)
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
		SupportState:         RuntimeExecutionPlanSupportStateSupported,
		RemoteEndpointFamily: RuntimeRemoteEndpointFamilyTURNServer,
		RemoteEndpointRole:   RuntimeRemoteEndpointRoleWireGuardRawDatagram,
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

func testWireGuardTransportProfileImportWithoutEndpoint(privateKey string) TransportProfileImportRequest {
	req := testWireGuardTransportProfileImport(privateKey)
	req.Material = strings.ReplaceAll(req.Material, "Endpoint = relay.example.test:51820\n", "")
	return req
}

func testStructuredWireGuardDraft() TransportProfileStructuredDraft {
	return TransportProfileStructuredDraft{
		Kind:                TransportProfileKindWireGuardNativeV1,
		SchemaVersion:       transportProfileStructuredWireGuardSchemaVersion,
		DisplayName:         "structured phone transport",
		InterfacePrivateKey: testWireGuardStructuredKey(1),
		InterfaceAddresses:  []string{"10.10.0.2/32"},
		DNSServers:          []string{"1.1.1.1"},
		MTU:                 1280,
		PeerPublicKey:       testWireGuardStructuredKey(2),
		AllowedIPs:          []string{"0.0.0.0/0"},
		Endpoint:            "relay.example.test:51820",
	}
}

func testGenericStructuredWireGuardDraft() TransportProfileStructuredDraft {
	return TransportProfileStructuredDraft{
		Kind:          TransportProfileKindWireGuardNativeV1,
		SchemaVersion: transportProfileStructuredWireGuardSchemaVersion,
		Fields: map[TransportProfileStructuredFieldID]any{
			TransportProfileStructuredFieldDisplayName:         "generic structured phone transport",
			TransportProfileStructuredFieldInterfaceAddresses:  []any{"10.66.0.2/32"},
			TransportProfileStructuredFieldDNSServers:          []any{"1.1.1.1"},
			TransportProfileStructuredFieldMTU:                 float64(1280),
			TransportProfileStructuredFieldPeerPublicKey:       testWireGuardStructuredKey(2),
			TransportProfileStructuredFieldPeerPresharedKey:    testWireGuardStructuredKey(4),
			TransportProfileStructuredFieldAllowedIPs:          []any{"0.0.0.0/0"},
			TransportProfileStructuredFieldEndpoint:            "relay.example.test:51820",
			TransportProfileStructuredFieldPersistentKeepalive: float64(23),
		},
		SecretActions: map[TransportProfileStructuredFieldID]TransportProfileSecretUpdateAction{
			TransportProfileStructuredFieldInterfacePrivateKey: TransportProfileSecretUpdateActionGenerateHost,
			TransportProfileStructuredFieldPeerPresharedKey:    TransportProfileSecretUpdateActionReplaceSubmitted,
		},
	}
}

func testWireGuardStructuredKey(seed byte) string {
	return base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{seed}, 32))
}

func testContainsCapability(capabilities []Capability, want Capability) bool {
	for _, capability := range capabilities {
		if capability == want {
			return true
		}
	}
	return false
}

func testContainsLifecycleAction(actions []TransportProfileLifecycleAction, want TransportProfileLifecycleAction) bool {
	for _, action := range actions {
		if action == want {
			return true
		}
	}
	return false
}

func testStructuredSchemaHasField(
	schema TransportProfileEditableKindSchema,
	fieldID TransportProfileStructuredFieldID,
	wantGenerated bool,
) bool {
	for _, field := range schema.Fields {
		if field.ID == fieldID && field.Generated == wantGenerated && field.UpdatePreservable {
			return true
		}
	}
	return false
}

func testValidationHasField(
	result TransportProfileStructuredValidationResult,
	field TransportProfileStructuredFieldID,
	violation string,
) bool {
	for _, err := range result.Errors {
		if err.Field == field && err.Violation == violation {
			return true
		}
	}
	return false
}
