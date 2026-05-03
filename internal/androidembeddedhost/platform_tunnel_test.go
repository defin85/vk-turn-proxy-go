package androidembeddedhost

import (
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestManagerReportsSupportedAndroidVPNServiceCapabilityFromController(t *testing.T) {
	t.Parallel()

	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability("packaged Android host owns android_vpn_service startup"),
		&fakeAndroidVPNServiceLifecycle{},
	)))
	baseURL := ensureStartedManager(t, manager)

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(baseURL + "/v1/host")
	if err != nil {
		t.Fatalf("GET /v1/host error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /v1/host status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var info clientcontrol.HostInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		t.Fatalf("decode host info: %v", err)
	}
	if len(info.PlatformTunnels) != 1 {
		t.Fatalf("platform_tunnels len = %d, want 1", len(info.PlatformTunnels))
	}
	capability := info.PlatformTunnels[0]
	if capability.Mode != clientcontrol.PlatformTunnelModeAndroidVPNService {
		t.Fatalf("platform_tunnels[0].mode = %q, want %q", capability.Mode, clientcontrol.PlatformTunnelModeAndroidVPNService)
	}
	if !capability.Available {
		t.Fatal("platform_tunnels[0].available = false, want supported android_vpn_service capability")
	}
	if len(capability.ExecutionPlans) != 1 {
		t.Fatalf("platform_tunnels[0].execution_plans len = %d, want 1", len(capability.ExecutionPlans))
	}
	if capability.ExecutionPlans[0].SupportState != clientcontrol.RuntimeExecutionPlanSupportStateUnavailable {
		t.Fatalf(
			"platform_tunnels[0].execution_plans[0].support_state = %q, want %q",
			capability.ExecutionPlans[0].SupportState,
			clientcontrol.RuntimeExecutionPlanSupportStateUnavailable,
		)
	}
	if capability.ExecutionPlans[0].TransportProfile == nil {
		t.Fatal("platform_tunnels[0].execution_plans[0].transport_profile = nil, want missing profile status")
	}
	if capability.ExecutionPlans[0].TransportProfile.MissingKind != clientcontrol.TransportProfileKindWireGuardNativeV1 {
		t.Fatalf(
			"transport_profile.missing_kind = %q, want %q",
			capability.ExecutionPlans[0].TransportProfile.MissingKind,
			clientcontrol.TransportProfileKindWireGuardNativeV1,
		)
	}
	if capability.ExecutionPlans[0].Plan.HostAdapter != clientcontrol.RuntimeHostAdapterAndroidVPNService {
		t.Fatalf(
			"platform_tunnels[0].execution_plans[0].plan.host_adapter = %q, want %q",
			capability.ExecutionPlans[0].Plan.HostAdapter,
			clientcontrol.RuntimeHostAdapterAndroidVPNService,
		)
	}
	if len(capability.SupportedUnderlayRoutePolicies) != 2 {
		t.Fatalf("platform_tunnels[0].supported_underlay_route_policies len = %d, want 2", len(capability.SupportedUnderlayRoutePolicies))
	}
	if capability.SupportedUnderlayRoutePolicies[0] != clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard {
		t.Fatalf(
			"platform_tunnels[0].supported_underlay_route_policies[0] = %q, want %q",
			capability.SupportedUnderlayRoutePolicies[0],
			clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard,
		)
	}
	if capability.SupportedUnderlayRoutePolicies[1] != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf(
			"platform_tunnels[0].supported_underlay_route_policies[1] = %q, want %q",
			capability.SupportedUnderlayRoutePolicies[1],
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		)
	}
}

func TestManagerPersistsTransportProfileStoreAcrossRestarts(t *testing.T) {
	t.Parallel()

	storePath := filepath.Join(t.TempDir(), "no-backup", "vpn-transport-profiles", "store.json")
	manager := New(
		WithTransportProfileStorePath(storePath),
		withPlatformTunnelController(newAndroidVPNServiceController(
			supportedAndroidVPNServiceCapability(""),
			&fakeAndroidVPNServiceLifecycle{},
		)),
	)
	baseURL := ensureStartedManager(t, manager)
	status := importAndroidWireGuardTransportProfile(t, baseURL)
	if err := manager.Stop(); err != nil {
		t.Fatalf("Stop() error = %v", err)
	}

	restored := New(
		WithTransportProfileStorePath(storePath),
		withPlatformTunnelController(newAndroidVPNServiceController(
			supportedAndroidVPNServiceCapability(""),
			&fakeAndroidVPNServiceLifecycle{},
		)),
	)
	restoredURL := ensureStartedManager(t, restored)
	profiles := getAndroidTransportProfiles(t, restoredURL)
	if len(profiles) != 1 || profiles[0].ID != status.ID {
		t.Fatalf("restored transport profiles = %+v, want %s", profiles, status.ID)
	}
	body, err := json.Marshal(profiles)
	if err != nil {
		t.Fatalf("Marshal(profiles) error = %v", err)
	}
	if strings.Contains(string(body), "client-private-key") {
		t.Fatalf("ordinary profile read leaked private key: %s", body)
	}
	if strings.Contains(string(body), storePath) {
		t.Fatalf("ordinary profile read leaked store path: %s", body)
	}
}

func TestManagerPersistsStructuredTransportProfileStoreAcrossRestarts(t *testing.T) {
	t.Parallel()

	storePath := filepath.Join(t.TempDir(), "no-backup", "vpn-transport-profiles", "store.json")
	manager := New(
		WithTransportProfileStorePath(storePath),
		withPlatformTunnelController(newAndroidVPNServiceController(
			supportedAndroidVPNServiceCapability(""),
			&fakeAndroidVPNServiceLifecycle{},
		)),
	)
	baseURL := ensureStartedManager(t, manager)
	status := createAndroidStructuredWireGuardTransportProfile(t, baseURL)
	if err := manager.Stop(); err != nil {
		t.Fatalf("Stop() error = %v", err)
	}

	restored := New(
		WithTransportProfileStorePath(storePath),
		withPlatformTunnelController(newAndroidVPNServiceController(
			supportedAndroidVPNServiceCapability(""),
			&fakeAndroidVPNServiceLifecycle{},
		)),
	)
	restoredURL := ensureStartedManager(t, restored)
	profiles := getAndroidTransportProfiles(t, restoredURL)
	if len(profiles) != 1 || profiles[0].ID != status.ID {
		t.Fatalf("restored structured profiles = %+v, want %s", profiles, status.ID)
	}
	if profiles[0].SecretMaterialRef.Kind != clientcontrol.TransportProfileMaterialSourceStructured {
		t.Fatalf(
			"secret material source = %q, want %q",
			profiles[0].SecretMaterialRef.Kind,
			clientcontrol.TransportProfileMaterialSourceStructured,
		)
	}
	body, err := json.Marshal(profiles)
	if err != nil {
		t.Fatalf("Marshal(profiles) error = %v", err)
	}
	if strings.Contains(string(body), androidWireGuardStructuredKey(3)) ||
		strings.Contains(string(body), storePath) {
		t.Fatalf("ordinary structured profile read leaked secret/store details: %s", body)
	}
}

func TestManagerMigratesLegacyAndroidWireGuardPathIntoTransportProfileStoreOnce(t *testing.T) {
	legacyPath := filepath.Join(t.TempDir(), "wireguard", "android-vpn-service.conf")
	if err := os.MkdirAll(filepath.Dir(legacyPath), 0o700); err != nil {
		t.Fatalf("MkdirAll(legacy): %v", err)
	}
	if err := os.WriteFile(legacyPath, []byte(strings.Join([]string{
		"[Interface]",
		"PrivateKey = legacy-client-key",
		"Address = 10.10.0.2/32",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"AllowedIPs = 0.0.0.0/0",
		"Endpoint = relay.example.test:51820",
		"",
	}, "\n")), 0o600); err != nil {
		t.Fatalf("WriteFile(legacy): %v", err)
	}
	SetAndroidWireGuardProfilePath(legacyPath)
	t.Cleanup(func() { SetAndroidWireGuardProfilePath("") })

	storePath := filepath.Join(t.TempDir(), "no-backup", "vpn-transport-profiles", "store.json")
	manager := New(
		WithTransportProfileStorePath(storePath),
		withPlatformTunnelController(newAndroidVPNServiceController(
			supportedAndroidVPNServiceCapability(""),
			&fakeAndroidVPNServiceLifecycle{},
		)),
	)
	baseURL := ensureStartedManager(t, manager)
	profiles := getAndroidTransportProfiles(t, baseURL)
	if len(profiles) != 1 {
		t.Fatalf("transport profiles len = %d, want migrated profile", len(profiles))
	}
	if profiles[0].SecretMaterialRef.Kind != clientcontrol.TransportProfileMaterialSourceLegacyPath {
		t.Fatalf("secret material source = %q, want %q", profiles[0].SecretMaterialRef.Kind, clientcontrol.TransportProfileMaterialSourceLegacyPath)
	}
	body, err := json.Marshal(profiles)
	if err != nil {
		t.Fatalf("Marshal(profiles) error = %v", err)
	}
	if strings.Contains(string(body), "legacy-client-key") || strings.Contains(string(body), legacyPath) {
		t.Fatalf("migrated profile ordinary read leaked legacy material/path: %s", body)
	}
	if _, err := os.Stat(legacyPath); !os.IsNotExist(err) {
		t.Fatalf("legacy profile path stat error = %v, want removed after migration", err)
	}

	info := getAndroidHostInfo(t, baseURL)
	plan := info.PlatformTunnels[0].ExecutionPlans[0]
	if plan.TransportProfile == nil || plan.TransportProfile.SelectedProfile == nil {
		t.Fatalf("execution plan transport profile = %+v, want migrated selected profile", plan.TransportProfile)
	}
	if plan.TransportProfile.SelectedProfile.ProfileID != profiles[0].ID {
		t.Fatalf("selected profile id = %q, want %q", plan.TransportProfile.SelectedProfile.ProfileID, profiles[0].ID)
	}
}

func TestManagerReportsInvalidLegacyAndroidWireGuardPathAsRedactedTransportProfile(t *testing.T) {
	legacyPath := filepath.Join(t.TempDir(), "wireguard", "android-vpn-service.conf")
	if err := os.MkdirAll(filepath.Dir(legacyPath), 0o700); err != nil {
		t.Fatalf("MkdirAll(legacy): %v", err)
	}
	if err := os.WriteFile(legacyPath, []byte(strings.Join([]string{
		"[Interface]",
		"Address = 10.10.0.2/32",
		"",
		"[Peer]",
		"PublicKey = peer-public-key",
		"AllowedIPs = 0.0.0.0/0",
		"Endpoint = relay.example.test:51820",
		"",
	}, "\n")), 0o600); err != nil {
		t.Fatalf("WriteFile(legacy): %v", err)
	}
	SetAndroidWireGuardProfilePath(legacyPath)
	t.Cleanup(func() { SetAndroidWireGuardProfilePath("") })

	storePath := filepath.Join(t.TempDir(), "no-backup", "vpn-transport-profiles", "store.json")
	manager := New(
		WithTransportProfileStorePath(storePath),
		withPlatformTunnelController(newAndroidVPNServiceController(
			supportedAndroidVPNServiceCapability(""),
			&fakeAndroidVPNServiceLifecycle{},
		)),
	)
	baseURL := ensureStartedManager(t, manager)
	profiles := getAndroidTransportProfiles(t, baseURL)
	if len(profiles) != 1 {
		t.Fatalf("transport profiles len = %d, want invalid legacy profile", len(profiles))
	}
	if profiles[0].Validation.State != clientcontrol.TransportProfileValidationStateInvalid {
		t.Fatalf("validation state = %q, want %q", profiles[0].Validation.State, clientcontrol.TransportProfileValidationStateInvalid)
	}
	if profiles[0].SecretMaterialRef.Kind != clientcontrol.TransportProfileMaterialSourceLegacyPath {
		t.Fatalf("secret material source = %q, want %q", profiles[0].SecretMaterialRef.Kind, clientcontrol.TransportProfileMaterialSourceLegacyPath)
	}
	body, err := json.Marshal(profiles)
	if err != nil {
		t.Fatalf("Marshal(profiles) error = %v", err)
	}
	if strings.Contains(string(body), legacyPath) || strings.Contains(string(body), "10.10.0.2") || strings.Contains(string(body), "peer-public-key") {
		t.Fatalf("invalid legacy profile ordinary read leaked legacy material/path: %s", body)
	}
	if _, err := os.Stat(legacyPath); err != nil {
		t.Fatalf("legacy profile path stat error = %v, want invalid file retained for operator recovery", err)
	}

	info := getAndroidHostInfo(t, baseURL)
	plan := info.PlatformTunnels[0].ExecutionPlans[0]
	if plan.TransportProfile == nil || plan.TransportProfile.State != clientcontrol.TransportProfileCompatibilityStateIncompatible {
		t.Fatalf("execution plan transport profile = %+v, want incompatible invalid legacy status", plan.TransportProfile)
	}
}

func TestAndroidKotlinUsesNoBackupTransportProfileStorePath(t *testing.T) {
	t.Parallel()

	sourcePath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"kotlin",
		"com",
		"defin85",
		"relaydock",
		"EmbeddedMobileHost.kt",
	)
	data, err := os.ReadFile(sourcePath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", sourcePath, err)
	}
	source := string(data)
	if !strings.Contains(source, "context.noBackupFilesDir") {
		t.Fatalf("EmbeddedMobileHost.kt does not configure transport profile store under noBackupFilesDir")
	}
	if strings.Contains(source, "File(context.filesDir, TRANSPORT_PROFILE_STORE_PATH)") {
		t.Fatalf("EmbeddedMobileHost.kt stores transport profile store under filesDir instead of noBackupFilesDir")
	}
}

func TestAndroidShellDoesNotExposeLegacyWireGuardProfilePathBridge(t *testing.T) {
	t.Parallel()

	sources := []string{
		filepath.Join(
			"..",
			"..",
			"mobile",
			"gui_shell",
			"android",
			"app",
			"src",
			"main",
			"kotlin",
			"com",
			"defin85",
			"relaydock",
			"MainActivity.kt",
		),
		filepath.Join(
			"..",
			"..",
			"mobile",
			"gui_shell",
			"android",
			"app",
			"src",
			"main",
			"kotlin",
			"com",
			"defin85",
			"relaydock",
			"EmbeddedMobileHost.kt",
		),
		filepath.Join(
			"..",
			"..",
			"mobile",
			"gui_shell",
			"lib",
			"src",
			"control",
			"mobile_host_bridge.dart",
		),
	}
	for _, sourcePath := range sources {
		data, err := os.ReadFile(sourcePath)
		if err != nil {
			t.Fatalf("ReadFile(%s): %v", sourcePath, err)
		}
		source := string(data)
		for _, forbidden := range []string{
			"getAndroidWireGuardProfileStatus",
			"configureAndroidWireGuardProfile",
			"clearAndroidWireGuardProfile",
			"PlatformAndroidWireGuardProfileManager",
		} {
			if strings.Contains(source, forbidden) {
				t.Fatalf("%s still exposes legacy WireGuard profile path bridge %q", sourcePath, forbidden)
			}
		}
	}
}

func TestAndroidNativeVPNPrimitivesStayBehindHostBoundary(t *testing.T) {
	t.Parallel()

	servicePath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"kotlin",
		"com",
		"defin85",
		"relaydock",
		"AndroidPlatformTunnelService.kt",
	)
	serviceData, err := os.ReadFile(servicePath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", servicePath, err)
	}
	service := string(serviceData)
	for _, required := range []string{
		"class AndroidPlatformTunnelService : VpnService()",
		"Builder()",
		"builder.establish()",
		"startForeground(NOTIFICATION_ID, buildNotification())",
		"service.protect(fd)",
		"activeTun",
	} {
		if !strings.Contains(service, required) {
			t.Fatalf("AndroidPlatformTunnelService.kt is missing native boundary primitive %q", required)
		}
	}

	bridgePath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"kotlin",
		"com",
		"defin85",
		"relaydock",
		"AndroidPlatformTunnelBridge.kt",
	)
	bridgeData, err := os.ReadFile(bridgePath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", bridgePath, err)
	}
	bridge := string(bridgeData)
	for _, required := range []string{
		"AndroidPlatformTunnelService.bringup",
		"AndroidPlatformTunnelService.protectSocket",
		"AndroidPlatformTunnelService.duplicateTunFd",
		"AndroidPlatformTunnelService.cleanup",
	} {
		if !strings.Contains(bridge, required) {
			t.Fatalf("AndroidPlatformTunnelBridge.kt is missing host/native bridge call %q", required)
		}
	}

	dartSources := []string{
		filepath.Join(
			"..",
			"..",
			"mobile",
			"gui_shell",
			"lib",
			"src",
			"control",
			"mobile_host_bridge.dart",
		),
		filepath.Join(
			"..",
			"..",
			"mobile",
			"gui_shell",
			"lib",
			"src",
			"control",
			"mobile_shell_controller.dart",
		),
	}
	for _, sourcePath := range dartSources {
		data, err := os.ReadFile(sourcePath)
		if err != nil {
			t.Fatalf("ReadFile(%s): %v", sourcePath, err)
		}
		source := string(data)
		for _, forbidden := range []string{
			"android.net.VpnService",
			": VpnService",
			"Builder.establish",
			"bringupAndroidVpnHost",
			"protectAndroidVpnSocket",
			"duplicateAndroidVpnTunFd",
			"cleanupAndroidVpnHost",
		} {
			if strings.Contains(source, forbidden) {
				t.Fatalf("%s owns native VPN primitive %q outside the host/native boundary", sourcePath, forbidden)
			}
		}
	}
}

func TestAndroidVPNServiceHandlesSystemLifecycleHooksFailClosed(t *testing.T) {
	t.Parallel()

	servicePath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"kotlin",
		"com",
		"defin85",
		"relaydock",
		"AndroidPlatformTunnelService.kt",
	)
	serviceData, err := os.ReadFile(servicePath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", servicePath, err)
	}
	service := string(serviceData)
	for _, required := range []string{
		"override fun onRevoke()",
		"override fun onDestroy()",
		"cleanupTunnelLocked()",
		"activeService = null",
		"Android VpnService.Builder.establish() returned null.",
	} {
		if !strings.Contains(service, required) {
			t.Fatalf("AndroidPlatformTunnelService.kt is missing system lifecycle handling %q", required)
		}
	}

	manifestPath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"AndroidManifest.xml",
	)
	manifestData, err := os.ReadFile(manifestPath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", manifestPath, err)
	}
	manifest := string(manifestData)
	for _, required := range []string{
		`android:name="android.net.VpnService.SUPPORTS_ALWAYS_ON"`,
		`android:value="false"`,
	} {
		if !strings.Contains(manifest, required) {
			t.Fatalf("AndroidManifest.xml is missing always-on opt-out %q", required)
		}
	}
}

func TestProductNativeVPNPathDoesNotDependOnExternalWireGuardApp(t *testing.T) {
	t.Parallel()

	sourceRoots := []string{
		filepath.Join("..", "..", "internal", "androidembeddedhost"),
		filepath.Join("..", "..", "mobile", "gui_shell", "android", "app", "src", "main"),
		filepath.Join("..", "..", "mobile", "gui_shell", "lib"),
	}
	for _, root := range sourceRoots {
		err := filepath.WalkDir(root, func(path string, entry os.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if entry.IsDir() {
				return nil
			}
			if strings.HasSuffix(path, "_test.go") {
				return nil
			}
			switch filepath.Ext(path) {
			case ".go", ".kt", ".kts", ".cpp", ".h", ".dart", ".xml":
			default:
				return nil
			}
			data, err := os.ReadFile(path)
			if err != nil {
				return err
			}
			source := string(data)
			for _, forbidden := range []string{
				"com.wireguard.android",
				"wireguard.android",
			} {
				if strings.Contains(source, forbidden) {
					t.Fatalf("%s depends on external WireGuard app token %q", path, forbidden)
				}
			}
			return nil
		})
		if err != nil {
			t.Fatalf("WalkDir(%s): %v", root, err)
		}
	}
}

func TestAndroidPermissionBridgeRepresentsDenialAndCancellation(t *testing.T) {
	t.Parallel()

	sourcePath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"kotlin",
		"com",
		"defin85",
		"relaydock",
		"MainActivity.kt",
	)
	data, err := os.ReadFile(sourcePath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", sourcePath, err)
	}
	source := string(data)
	for _, required := range []string{
		"finishPlatformTunnelPermissionRequest(resultCode == Activity.RESULT_OK)",
		"finishPlatformTunnelPermissionRequest(null)",
		"platform_tunnel_permission_cancelled",
		"pending.success(granted)",
	} {
		if !strings.Contains(source, required) {
			t.Fatalf("MainActivity.kt is missing Android VPN permission outcome handling %q", required)
		}
	}
}

func TestAndroidManifestUsesNarrowPackageVisibilityForVPNAppScope(t *testing.T) {
	t.Parallel()

	manifestPath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"AndroidManifest.xml",
	)
	manifestData, err := os.ReadFile(manifestPath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", manifestPath, err)
	}
	manifest := string(manifestData)
	if strings.Contains(manifest, "android.permission.QUERY_ALL_PACKAGES") {
		t.Fatalf("AndroidManifest.xml requests QUERY_ALL_PACKAGES; native VPN app-scope release strategy must stay narrow")
	}
	for _, required := range []string{
		"<queries>",
		"android.intent.action.VIEW",
		"android.intent.action.PROCESS_TEXT",
		`android:name="android.net.VpnService.SUPPORTS_ALWAYS_ON"`,
		`android:value="false"`,
	} {
		if !strings.Contains(manifest, required) {
			t.Fatalf("AndroidManifest.xml is missing narrow package visibility declaration %q", required)
		}
	}

	bridgePath := filepath.Join(
		"..",
		"..",
		"mobile",
		"gui_shell",
		"android",
		"app",
		"src",
		"main",
		"kotlin",
		"com",
		"defin85",
		"relaydock",
		"AndroidPlatformTunnelBridge.kt",
	)
	bridgeData, err := os.ReadFile(bridgePath)
	if err != nil {
		t.Fatalf("ReadFile(%s): %v", bridgePath, err)
	}
	bridge := string(bridgeData)
	if !strings.Contains(bridge, "packageManager.getApplicationInfo(packageName, 0)") {
		t.Fatalf("AndroidPlatformTunnelBridge.kt no longer validates operator-provided package names")
	}
}

func TestManagerPlatformTunnelStartPermissionAcquireFailureStaysFailClosed(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		acquirePermissionErr: errors.New("operator denied Android VpnService permission"),
	}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)
	importAndroidWireGuardTransportProfile(t, baseURL)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanup calls = %d, want 0", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission" {
		t.Fatalf("lifecycle calls = %q, want %q", got, "acquire_permission")
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestManagerPlatformTunnelResumePermissionDenialStaysFailClosed(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		acquirePermissionErr: newAndroidPermissionPendingError("android vpn permission prompt launched"),
		resumePermissionErr:  errors.New("operator denied Android VpnService permission"),
	}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)
	importAndroidWireGuardTransportProfile(t, baseURL)

	startResult := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})
	if strings.TrimSpace(startResult.StartupAttemptID) == "" {
		t.Fatal("startup attempt id = empty, want resumable attempt")
	}

	resumeResult := resumePlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelResumeRequest{
		StartupAttemptID: startResult.StartupAttemptID,
	})
	if resumeResult.Ready {
		t.Fatalf("platform tunnel resume result ready = true, want false: %+v", resumeResult)
	}
	if resumeResult.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("platform tunnel resume stage = %q, want %q", resumeResult.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if resumeResult.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"platform tunnel resume missing_prerequisite = %q, want %q",
			resumeResult.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanup calls = %d, want 0 before native resources are acquired", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,resume_after_permission" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,resume_after_permission",
		)
	}
	assertAndroidVPNExecutionPlan(t, resumeResult.ExecutionPlan)
}

func TestManagerPlatformTunnelStartReturnsResumablePermissionAttempt(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		acquirePermissionErr: newAndroidPermissionPendingError("android vpn permission prompt launched"),
	}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)
	importAndroidWireGuardTransportProfile(t, baseURL)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStagePermissionAcquire {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStagePermissionAcquire)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisitePermission {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisitePermission,
		)
	}
	if strings.TrimSpace(result.StartupAttemptID) == "" {
		t.Fatal("platform tunnel start startup_attempt_id = empty, want resumable attempt id")
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanup calls = %d, want 0", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission" {
		t.Fatalf("lifecycle calls = %q, want %q", got, "acquire_permission")
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestManagerPlatformTunnelResumeContinuesAfterPermissionGrantAndFailsWithoutMaterializedRuntime(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		acquirePermissionErr: newAndroidPermissionPendingError("android vpn permission prompt launched"),
	}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)
	importAndroidWireGuardTransportProfile(t, baseURL)

	startResult := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if strings.TrimSpace(startResult.StartupAttemptID) == "" {
		t.Fatal("startup attempt id = empty, want resumable attempt")
	}

	resumeResult := resumePlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelResumeRequest{
		StartupAttemptID: startResult.StartupAttemptID,
	})
	if resumeResult.Ready {
		t.Fatalf("platform tunnel resume result ready = true, want false: %+v", resumeResult)
	}
	if resumeResult.Stage != clientcontrol.PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("platform tunnel resume stage = %q, want %q", resumeResult.Stage, clientcontrol.PlatformTunnelStartupStageRuntimeAttach)
	}
	if resumeResult.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform tunnel resume missing_prerequisite = %q, want %q",
			resumeResult.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if !strings.Contains(strings.ToLower(resumeResult.Message), "resolution") {
		t.Fatalf("platform tunnel resume message = %q, want resolution-related failure", resumeResult.Message)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,resume_after_permission,validate_route_policy,cleanup" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,resume_after_permission,validate_route_policy,cleanup",
		)
	}
	assertAndroidVPNExecutionPlan(t, resumeResult.ExecutionPlan)
}

func TestManagerPlatformTunnelStartRouteValidationFailureCleansUp(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name                 string
		err                  error
		wantPrerequisite     clientcontrol.PlatformTunnelPrerequisite
		wantMessageSubstring string
	}{
		{
			name:                 "route exclusion",
			err:                  newAndroidRouteExclusionError("control-plane route exclusion is unsafe"),
			wantPrerequisite:     clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
			wantMessageSubstring: "route exclusion",
		},
		{
			name:                 "dns bypass",
			err:                  newAndroidDNSBypassError("provider DNS bypass cannot be applied safely"),
			wantPrerequisite:     clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			wantMessageSubstring: "DNS bypass",
		},
		{
			name:                 "app routing policy",
			err:                  newAndroidAppRoutingPolicyError("requested package allowlist is invalid"),
			wantPrerequisite:     clientcontrol.PlatformTunnelPrerequisiteAppRoutingPolicy,
			wantMessageSubstring: "allowlist",
		},
	}

	for _, tc := range testCases {
		tc := tc
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			lifecycle := &fakeAndroidVPNServiceLifecycle{
				validateRouteErr: tc.err,
			}
			manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
				supportedAndroidVPNServiceCapability(""),
				lifecycle,
			)))
			baseURL := ensureStartedManager(t, manager)
			importAndroidWireGuardTransportProfile(t, baseURL)

			result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
				Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
			})

			if result.Ready {
				t.Fatal("platform tunnel start result ready = true, want false")
			}
			if result.Stage != clientcontrol.PlatformTunnelStartupStageRouteValidate {
				t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageRouteValidate)
			}
			if result.MissingPrerequisite != tc.wantPrerequisite {
				t.Fatalf("platform tunnel start missing_prerequisite = %q, want %q", result.MissingPrerequisite, tc.wantPrerequisite)
			}
			if !strings.Contains(strings.ToLower(result.Message), strings.ToLower(tc.wantMessageSubstring)) {
				t.Fatalf("platform tunnel start message = %q, want substring %q", result.Message, tc.wantMessageSubstring)
			}
			if lifecycle.cleanupCalls != 1 {
				t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
			}
			if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,cleanup" {
				t.Fatalf(
					"lifecycle calls = %q, want %q",
					got,
					"acquire_permission,validate_route_policy,cleanup",
				)
			}
			assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
		})
	}
}

func TestManagerPlatformTunnelStartRejectsUnsupportedUnderlayRoutePolicyBeforePermissionPrompt(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		clientcontrol.PlatformTunnelCapability{
			Mode:      clientcontrol.PlatformTunnelModeAndroidVPNService,
			Available: true,
			SatisfiedPrerequisites: []clientcontrol.PlatformTunnelPrerequisite{
				clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
				clientcontrol.PlatformTunnelPrerequisiteDNSBypass,
			},
			SupportedUnderlayRoutePolicies: []clientcontrol.PlatformTunnelUnderlayRoutePolicy{
				clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard,
			},
			ExecutionPlans: androidVPNServiceExecutionPlans(true, ""),
		},
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)
	importAndroidWireGuardTransportProfile(t, baseURL)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode:                clientcontrol.PlatformTunnelModeAndroidVPNService,
		UnderlayRoutePolicy: clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageCapabilityCheck {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageCapabilityCheck)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteRouteExclusion {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteRouteExclusion,
		)
	}
	if result.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork {
		t.Fatalf(
			"platform tunnel start underlay_route_policy = %q, want %q",
			result.UnderlayRoutePolicy,
			clientcontrol.PlatformTunnelUnderlayRoutePolicyPreserveActiveLocalNetwork,
		)
	}
	if len(lifecycle.calls) != 0 {
		t.Fatalf("lifecycle calls = %+v, want none before permission acquire", lifecycle.calls)
	}
}

func TestManagerPlatformTunnelStartHostBringupFailureCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		bringupErr: errors.New("android VpnService interface setup failed"),
	}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	controller.setWireGuardTurnLeaseProvider(testWireGuardTurnLeaseProvider())
	manager := New(WithHostFactory(testHostFactory(controller, nil)))
	baseURL := ensureStartedManager(t, manager)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageHostBringup {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageHostBringup)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if lifecycle.cleanupCalls != 1 {
		t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,bringup_host,cleanup" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,validate_route_policy,bringup_host,cleanup",
		)
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestManagerPlatformTunnelStartRuntimeAttachFailureCleansUp(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{
		attachErr: errors.New("android shared runtime attach failed"),
	}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	controller.setWireGuardTurnLeaseProvider(testWireGuardTurnLeaseProvider())
	manager := New(WithHostFactory(testHostFactory(controller, nil)))
	baseURL := ensureStartedManager(t, manager)

	result := startPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})

	if result.Ready {
		t.Fatal("platform tunnel start result ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageRuntimeAttach {
		t.Fatalf("platform tunnel start stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageRuntimeAttach)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteHostImplementation {
		t.Fatalf(
			"platform tunnel start missing_prerequisite = %q, want %q",
			result.MissingPrerequisite,
			clientcontrol.PlatformTunnelPrerequisiteHostImplementation,
		)
	}
	if !strings.Contains(strings.ToLower(result.Message), "runtime attach") {
		t.Fatalf("platform tunnel start message = %q, want runtime-attach-related failure", result.Message)
	}
	if lifecycle.cleanupCalls != 1 {
		t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,bringup_host,attach_runtime,cleanup" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,validate_route_policy,bringup_host,attach_runtime,cleanup",
		)
	}
	assertAndroidVPNExecutionPlan(t, result.ExecutionPlan)
}

func TestAndroidVPNServiceControllerMapsTransportProfileLeaseFailureToProfileValidate(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	controller.setWireGuardTurnLeaseProvider(func(
		context.Context,
		clientcontrol.PlatformTunnelStartRequest,
		*clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		return nil, fmt.Errorf("%w: strict WireGuard profile materialization requires a peer endpoint address", clientcontrol.ErrTransportProfileInvalid)
	})

	_, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
		},
	})
	var startErr *clientcontrol.PlatformTunnelStartError
	if !errors.As(err, &startErr) {
		t.Fatalf("controller.Start() error = %v, want PlatformTunnelStartError", err)
	}
	result := startErr.Result
	if result.Ready {
		t.Fatal("controller.Start() ready = true, want false")
	}
	if result.Stage != clientcontrol.PlatformTunnelStartupStageProfileValidate {
		t.Fatalf("controller.Start() stage = %q, want %q", result.Stage, clientcontrol.PlatformTunnelStartupStageProfileValidate)
	}
	if result.MissingPrerequisite != clientcontrol.PlatformTunnelPrerequisiteTransportProfile {
		t.Fatalf("controller.Start() missing_prerequisite = %q, want %q", result.MissingPrerequisite, clientcontrol.PlatformTunnelPrerequisiteTransportProfile)
	}
	if !strings.Contains(strings.ToLower(result.Message), "peer endpoint") {
		t.Fatalf("controller.Start() message = %q, want profile materialization detail", result.Message)
	}
	if lifecycle.cleanupCalls != 0 {
		t.Fatalf("cleanup calls = %d, want 0", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy" {
		t.Fatalf("lifecycle calls = %q, want %q", got, "acquire_permission,validate_route_policy")
	}
}

func TestManagerPlatformTunnelStopCleansUpActiveAndroidVPNService(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	manager := New(withPlatformTunnelController(newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	)))
	baseURL := ensureStartedManager(t, manager)

	result := stopPlatformTunnel(t, baseURL, clientcontrol.PlatformTunnelStopRequest{
		Mode: clientcontrol.PlatformTunnelModeAndroidVPNService,
	})

	if result.Mode != clientcontrol.PlatformTunnelModeAndroidVPNService {
		t.Fatalf("platform tunnel stop mode = %q, want %q", result.Mode, clientcontrol.PlatformTunnelModeAndroidVPNService)
	}
	if !result.Stopped {
		t.Fatal("platform tunnel stop stopped = false, want true")
	}
	if lifecycle.cleanupCalls != 1 {
		t.Fatalf("cleanup calls = %d, want 1", lifecycle.cleanupCalls)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "cleanup" {
		t.Fatalf("lifecycle calls = %q, want %q", got, "cleanup")
	}
}

func TestAndroidVPNServiceControllerPassesMaterializedLeaseToRuntimeAttach(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	controller.setWireGuardTurnLeaseProvider(testWireGuardTurnLeaseProvider())

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: "resolution-android-1",
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
			PeerAddr:   "relay.example.test:3478",
		},
	})
	if err != nil {
		t.Fatalf("controller.Start() error = %v", err)
	}
	if !result.Ready {
		t.Fatalf("controller.Start() ready = false, want true: %+v", result)
	}
	if result.RemoteIngress == nil {
		t.Fatal("controller.Start().RemoteIngress = nil, want raw WireGuard ingress diagnostics")
	}
	if result.RemoteIngress.Protocol != clientcontrol.RuntimeRemoteIngressProtocolRawWireGuard ||
		result.RemoteIngress.Address != "176.109.104.105:56042" ||
		result.RemoteIngress.Isolation != clientcontrol.RuntimeRemoteIngressIsolationDedicated {
		t.Fatalf("controller.Start().RemoteIngress = %+v, want raw WireGuard dedicated ingress", result.RemoteIngress)
	}
	if result.UnderlayRoutePolicy != clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard {
		t.Fatalf("controller.Start() underlay_route_policy = %q, want %q", result.UnderlayRoutePolicy, clientcontrol.PlatformTunnelUnderlayRoutePolicyStandard)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,bringup_host,attach_runtime" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,validate_route_policy,bringup_host,attach_runtime",
		)
	}
	if len(lifecycle.attachedLeasePresence) != 1 || !lifecycle.attachedLeasePresence[0] {
		t.Fatalf("attached lease presence = %+v, want [true]", lifecycle.attachedLeasePresence)
	}
	if len(lifecycle.attachedLeaseIDs) != 1 || lifecycle.attachedLeaseIDs[0] != "resolution-android-1" {
		t.Fatalf("attached lease ids = %+v, want [resolution-android-1]", lifecycle.attachedLeaseIDs)
	}
}

func TestAndroidVPNServiceControllerAttachesStructuredProfileThroughResolvedArtifact(t *testing.T) {
	t.Parallel()

	lifecycle := &fakeAndroidVPNServiceLifecycle{}
	controller, ok := newAndroidVPNServiceController(
		supportedAndroidVPNServiceCapability(""),
		lifecycle,
	).(*androidVPNServiceController)
	if !ok {
		t.Fatal("newAndroidVPNServiceController() type assertion failed")
	}
	host := clientcontrol.New(
		clientcontrol.WithBuildIdentity(currentBuildIdentity()),
		clientcontrol.WithRegistry(provider.NewRegistry(fakeAndroidProviderAdapter{})),
		clientcontrol.WithVPNTransportProfileStore(),
		clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{
			controller.Capability(),
		}),
	)
	profile := createAndroidStructuredWireGuardTransportProfileOnHost(t, host)
	controller.setWireGuardTurnLeaseProvider(func(
		ctx context.Context,
		req clientcontrol.PlatformTunnelStartRequest,
		plan *clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		if req.RuntimeDefaults == nil {
			t.Fatal("RuntimeDefaults = nil, want explicit startup defaults")
		}
		return host.MaterializeWireGuardTurnExecutionLeaseForProfile(
			ctx,
			req.ResolutionID,
			*req.RuntimeDefaults,
			plan,
			req.TransportProfile,
		)
	})

	started, err := host.StartResolution(context.Background(), clientcontrol.StartResolutionRequest{
		Provider: "android-test",
		Input: &clientcontrol.ProviderInputEnvelope{
			Kind: clientcontrol.ProviderInputKindLink,
			Link: "https://calls.example.test/join/native-vpn",
		},
	})
	if err != nil {
		t.Fatalf("StartResolution() error = %v", err)
	}
	resolved, err := host.WaitResolution(context.Background(), started.ID)
	if err != nil {
		t.Fatalf("WaitResolution() error = %v", err)
	}
	if resolved.State != clientcontrol.ResolutionStateResolved {
		t.Fatalf("resolution state = %q, want %q", resolved.State, clientcontrol.ResolutionStateResolved)
	}

	result, err := controller.Start(context.Background(), clientcontrol.PlatformTunnelStartRequest{
		Mode:         clientcontrol.PlatformTunnelModeAndroidVPNService,
		ResolutionID: resolved.ID,
		RuntimeDefaults: &clientcontrol.RuntimeDefaults{
			ListenAddr: "127.0.0.1:7777",
		},
		TransportProfile: &clientcontrol.TransportProfileReference{
			ProfileID: profile.ID,
		},
	})
	if err != nil {
		t.Fatalf("controller.Start() error = %v", err)
	}
	if !result.Ready {
		t.Fatalf("controller.Start() ready = false, want true: %+v", result)
	}
	if got := strings.Join(lifecycle.calls, ","); got != "acquire_permission,validate_route_policy,bringup_host,attach_runtime" {
		t.Fatalf(
			"lifecycle calls = %q, want %q",
			got,
			"acquire_permission,validate_route_policy,bringup_host,attach_runtime",
		)
	}
	if len(lifecycle.attachedLeases) != 1 {
		t.Fatalf("attached leases len = %d, want 1", len(lifecycle.attachedLeases))
	}
	lease := lifecycle.attachedLeases[0]
	if lease.ResolutionID != resolved.ID {
		t.Fatalf("lease resolution_id = %q, want %q", lease.ResolutionID, resolved.ID)
	}
	if lease.TURNServerAddress != "turn.example.test:3478" ||
		lease.TURNUsername != "turn-user" ||
		lease.TURNPassword != "turn-pass" {
		t.Fatalf("lease TURN credentials = %+v, want fake provider credentials", lease)
	}
	if lease.PeerEndpointAddress != "relay.example.test:51820" {
		t.Fatalf("lease peer endpoint = %q, want profile endpoint", lease.PeerEndpointAddress)
	}
	if result.RemoteIngress == nil ||
		result.RemoteIngress.Protocol != clientcontrol.RuntimeRemoteIngressProtocolRawWireGuard ||
		result.RemoteIngress.Address != "relay.example.test:51820" {
		t.Fatalf("controller.Start().RemoteIngress = %+v, want profile endpoint ingress diagnostics", result.RemoteIngress)
	}
	if strings.TrimSpace(lease.ClientPrivateKey) == "" {
		t.Fatal("lease client private key = empty, want generated host-owned key")
	}
	if !stringSlicesEqual(lease.ClientAddresses, []string{"10.88.0.2/32"}) {
		t.Fatalf("lease client addresses = %+v, want [10.88.0.2/32]", lease.ClientAddresses)
	}
	if lease.PeerPublicKey != androidWireGuardStructuredKey(2) {
		t.Fatalf("lease peer public key = %q, want structured profile peer key", lease.PeerPublicKey)
	}
	if lease.PresharedKey != androidWireGuardStructuredKey(3) {
		t.Fatalf("lease preshared key = %q, want structured profile PSK", lease.PresharedKey)
	}
	if !stringSlicesEqual(lease.AllowedIPs, []string{"10.88.0.0/16"}) {
		t.Fatalf("lease allowed IPs = %+v, want [10.88.0.0/16]", lease.AllowedIPs)
	}
	if !stringSlicesEqual(lease.DNSServers, []string{"9.9.9.9"}) {
		t.Fatalf("lease DNS servers = %+v, want [9.9.9.9]", lease.DNSServers)
	}
	if lease.MTU != 1420 || lease.PersistentKeepaliveSeconds != 23 {
		t.Fatalf("lease mtu/keepalive = %d/%d, want 1420/23", lease.MTU, lease.PersistentKeepaliveSeconds)
	}
}

type fakeAndroidVPNServiceLifecycle struct {
	acquirePermissionErr error
	resumePermissionErr  error
	validateRouteErr     error
	bringupErr           error
	attachErr            error
	cleanupErr           error

	calls                 []string
	cleanupCalls          int
	attachedLeaseIDs      []string
	attachedLeasePresence []bool
	attachedLeases        []clientcontrol.WireGuardTurnExecutionLease
}

func (f *fakeAndroidVPNServiceLifecycle) AcquirePermission(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "acquire_permission")
	return f.acquirePermissionErr
}

func (f *fakeAndroidVPNServiceLifecycle) ResumeAfterPermission(_ context.Context, _ string, _ clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "resume_after_permission")
	return f.resumePermissionErr
}

func (f *fakeAndroidVPNServiceLifecycle) ValidateRoutePolicy(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest) error {
	f.calls = append(f.calls, "validate_route_policy")
	return f.validateRouteErr
}

func (f *fakeAndroidVPNServiceLifecycle) BringupHost(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest, _ *clientcontrol.RuntimeExecutionPlan, _ *clientcontrol.WireGuardTurnExecutionLease) error {
	f.calls = append(f.calls, "bringup_host")
	return f.bringupErr
}

func (f *fakeAndroidVPNServiceLifecycle) AttachRuntime(_ context.Context, _ clientcontrol.PlatformTunnelStartRequest, _ *clientcontrol.RuntimeExecutionPlan, lease *clientcontrol.WireGuardTurnExecutionLease) error {
	f.calls = append(f.calls, "attach_runtime")
	f.attachedLeasePresence = append(f.attachedLeasePresence, lease != nil)
	if lease != nil {
		f.attachedLeaseIDs = append(f.attachedLeaseIDs, lease.ResolutionID)
		f.attachedLeases = append(f.attachedLeases, cloneTestWireGuardTurnExecutionLease(*lease))
	} else {
		f.attachedLeaseIDs = append(f.attachedLeaseIDs, "")
	}
	return f.attachErr
}

func (f *fakeAndroidVPNServiceLifecycle) Cleanup(_ context.Context) error {
	f.calls = append(f.calls, "cleanup")
	f.cleanupCalls++
	return f.cleanupErr
}

func testWireGuardTurnLeaseProvider() androidVPNServiceLeaseProvider {
	return func(
		_ context.Context,
		req clientcontrol.PlatformTunnelStartRequest,
		plan *clientcontrol.RuntimeExecutionPlan,
	) (*clientcontrol.WireGuardTurnExecutionLease, error) {
		return &clientcontrol.WireGuardTurnExecutionLease{
			ResolutionID:         req.ResolutionID,
			AccessMethod:         plan.AccessMethod,
			CarrierFamily:        plan.CarrierFamily,
			EngineFamily:         plan.EngineFamily,
			RemoteEndpointFamily: clientcontrol.RuntimeRemoteEndpointFamilyTURNServer,
			RemoteEndpointRole:   clientcontrol.WireGuardTurnRemoteEndpointRoleDatagramTermination,
			TURNServerAddress:    "turn.example.test:3478",
			TURNUsername:         "turn-user",
			TURNPassword:         "turn-pass",
			PeerEndpointAddress:  "176.109.104.105:56042",
			ClientPrivateKey:     "privkey-test-123",
			ClientAddresses:      []string{"10.99.0.2/32"},
			PeerPublicKey:        "peerpub-test-123",
			AllowedIPs:           []string{"0.0.0.0/0"},
		}, nil
	}
}

type fakeAndroidProviderAdapter struct{}

func (fakeAndroidProviderAdapter) Name() string {
	return "android-test"
}

func (fakeAndroidProviderAdapter) Descriptor() provider.ProviderDescriptor {
	return provider.ProviderDescriptor{
		ID:            "android-test",
		DisplayName:   "Android test provider",
		InputKind:     provider.ProviderInputKindLink,
		AuthPosture:   provider.ProviderAuthPostureNotApplicable,
		BrowserPolicy: provider.ProviderBrowserPolicyNotRequired,
		ArtifactFamilies: []provider.ArtifactFamily{
			provider.ArtifactFamilyGenericTURN,
		},
		CapabilityHints: provider.ProviderCapabilityHints{
			PotentialActions: []provider.ArtifactAction{
				provider.ArtifactActionStartOnThisDevice,
			},
			RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
		},
	}
}

func (fakeAndroidProviderAdapter) Resolve(_ context.Context, _ string) (provider.Resolution, error) {
	return provider.Resolution{
		Credentials: provider.Credentials{
			Username: "turn-user",
			Password: "turn-pass",
			Address:  "turn.example.test:3478",
			TTL:      30 * time.Minute,
		},
		Metadata: map[string]string{
			"provider": "android-test",
		},
	}, nil
}

func cloneTestWireGuardTurnExecutionLease(lease clientcontrol.WireGuardTurnExecutionLease) clientcontrol.WireGuardTurnExecutionLease {
	lease.ClientAddresses = append([]string(nil), lease.ClientAddresses...)
	lease.AllowedIPs = append([]string(nil), lease.AllowedIPs...)
	lease.DNSServers = append([]string(nil), lease.DNSServers...)
	if lease.ExpiresAt != nil {
		expiresAt := lease.ExpiresAt.UTC()
		lease.ExpiresAt = &expiresAt
	}
	return lease
}

func createAndroidStructuredWireGuardTransportProfileOnHost(
	t *testing.T,
	host *clientcontrol.Host,
) clientcontrol.TransportProfileStatus {
	t.Helper()

	info := host.Info()
	if info.TransportProfileStore == nil || len(info.TransportProfileStore.EditableKinds) == 0 {
		t.Fatalf("transport_profile_store = %+v, want editable structured schema", info.TransportProfileStore)
	}
	if len(info.PlatformTunnels) == 0 || len(info.PlatformTunnels[0].ExecutionPlans) == 0 {
		t.Fatalf("platform_tunnels = %+v, want Android VPN service execution plan", info.PlatformTunnels)
	}
	schema := info.TransportProfileStore.EditableKinds[0]
	plan := info.PlatformTunnels[0].ExecutionPlans[0].Plan
	result, err := host.CreateStructuredTransportProfile(clientcontrol.TransportProfileStructuredCreateRequest{
		Draft: clientcontrol.TransportProfileStructuredDraft{
			Kind:                       clientcontrol.TransportProfileKindWireGuardNativeV1,
			SchemaVersion:              schema.SchemaVersion,
			DisplayName:                "Structured Android WireGuard profile",
			InterfacePrivateKeyAction:  clientcontrol.TransportProfileSecretUpdateActionGenerateHost,
			InterfaceAddresses:         []string{"10.88.0.2/32"},
			DNSServers:                 []string{"9.9.9.9"},
			MTU:                        1420,
			PeerPublicKey:              androidWireGuardStructuredKey(2),
			PeerPresharedKey:           androidWireGuardStructuredKey(3),
			PeerPresharedKeyAction:     clientcontrol.TransportProfileSecretUpdateActionReplaceSubmitted,
			AllowedIPs:                 []string{"10.88.0.0/16"},
			Endpoint:                   "relay.example.test:51820",
			PersistentKeepaliveSeconds: 23,
			DefaultFor:                 &plan,
		},
	})
	if err != nil {
		t.Fatalf("CreateStructuredTransportProfile() error = %v", err)
	}
	if result.Profile.ID == "" {
		t.Fatal("structured transport profile id = empty")
	}
	return result.Profile
}

func stringSlicesEqual(left []string, right []string) bool {
	if len(left) != len(right) {
		return false
	}
	for index := range left {
		if left[index] != right[index] {
			return false
		}
	}
	return true
}

func testHostFactory(
	controller platformTunnelController,
	materializer clientcontrol.WireGuardTurnMaterializer,
) func(*slog.Logger) *clientcontrol.Host {
	return func(logger *slog.Logger) *clientcontrol.Host {
		opts := []clientcontrol.Option{
			clientcontrol.WithLogger(logger),
			clientcontrol.WithBuildIdentity(currentBuildIdentity()),
			clientcontrol.WithRegistry(mobileProviderRegistry()),
			clientcontrol.WithInteractiveChallengeMetadataResolver(mobileChallengeMetadata),
		}
		if materializer != nil {
			opts = append(opts, clientcontrol.WithWireGuardTurnMaterializer(materializer))
		}
		if controller != nil {
			opts = append(opts,
				clientcontrol.WithPlatformTunnelCapabilities([]clientcontrol.PlatformTunnelCapability{
					controller.Capability(),
				}),
				clientcontrol.WithPlatformTunnelStarter(controller.Start),
				clientcontrol.WithPlatformTunnelResumer(controller.Resume),
				clientcontrol.WithPlatformTunnelStopper(controller.Stop),
			)
		}
		return clientcontrol.New(opts...)
	}
}

func ensureStartedManager(t *testing.T, manager *Manager) string {
	t.Helper()

	baseURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("EnsureStarted() error = %v", err)
	}
	t.Cleanup(func() {
		if err := manager.Stop(); err != nil {
			t.Fatalf("Stop() error = %v", err)
		}
	})
	return baseURL
}

func importAndroidWireGuardTransportProfile(t *testing.T, baseURL string) clientcontrol.TransportProfileStatus {
	t.Helper()

	req := clientcontrol.TransportProfileImportRequest{
		Adapter:     clientcontrol.TransportProfileImportAdapterWireGuardConf,
		Kind:        clientcontrol.TransportProfileKindWireGuardNativeV1,
		DisplayName: "Android WireGuard profile",
		Material: strings.Join([]string{
			"[Interface]",
			"PrivateKey = client-private-key",
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
	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/transport-profiles", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/transport-profiles error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/transport-profiles status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var status clientcontrol.TransportProfileStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		t.Fatalf("decode transport profile status: %v", err)
	}
	if status.ID == "" {
		t.Fatal("transport profile id = empty")
	}
	return status
}

func createAndroidStructuredWireGuardTransportProfile(t *testing.T, baseURL string) clientcontrol.TransportProfileStatus {
	t.Helper()

	info := getAndroidHostInfo(t, baseURL)
	if info.TransportProfileStore == nil || len(info.TransportProfileStore.EditableKinds) == 0 {
		t.Fatalf("transport_profile_store = %+v, want editable structured schema", info.TransportProfileStore)
	}
	schema := info.TransportProfileStore.EditableKinds[0]
	if len(info.PlatformTunnels) == 0 || len(info.PlatformTunnels[0].ExecutionPlans) == 0 {
		t.Fatalf("platform_tunnels = %+v, want Android VPN service execution plan", info.PlatformTunnels)
	}
	plan := info.PlatformTunnels[0].ExecutionPlans[0].Plan
	req := clientcontrol.TransportProfileStructuredCreateRequest{
		Draft: clientcontrol.TransportProfileStructuredDraft{
			Kind:                       clientcontrol.TransportProfileKindWireGuardNativeV1,
			SchemaVersion:              schema.SchemaVersion,
			DisplayName:                "Structured Android WireGuard profile",
			InterfacePrivateKeyAction:  clientcontrol.TransportProfileSecretUpdateActionGenerateHost,
			InterfaceAddresses:         []string{"10.88.0.2/32"},
			DNSServers:                 []string{"9.9.9.9"},
			MTU:                        1420,
			PeerPublicKey:              androidWireGuardStructuredKey(2),
			PeerPresharedKey:           androidWireGuardStructuredKey(3),
			PeerPresharedKeyAction:     clientcontrol.TransportProfileSecretUpdateActionReplaceSubmitted,
			AllowedIPs:                 []string{"10.88.0.0/16"},
			Endpoint:                   "relay.example.test:51820",
			PersistentKeepaliveSeconds: 23,
			DefaultFor:                 &plan,
		},
	}
	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/transport-profiles:structured", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/transport-profiles:structured error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("POST /v1/transport-profiles:structured status = %d, want %d: %s", resp.StatusCode, http.StatusOK, body)
	}
	var result clientcontrol.TransportProfileStructuredSaveResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode structured transport profile result: %v", err)
	}
	if result.Profile.ID == "" {
		t.Fatal("structured transport profile id = empty")
	}
	if len(result.GeneratedKeys) != 1 || strings.TrimSpace(result.GeneratedKeys[0].PublicKey) == "" {
		t.Fatalf("generated keys = %+v, want public-key metadata", result.GeneratedKeys)
	}
	return result.Profile
}

func androidWireGuardStructuredKey(value byte) string {
	return base64.StdEncoding.EncodeToString(bytes.Repeat([]byte{value}, 32))
}

func getAndroidHostInfo(t *testing.T, baseURL string) clientcontrol.HostInfo {
	t.Helper()

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(baseURL + "/v1/host")
	if err != nil {
		t.Fatalf("GET /v1/host error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("GET /v1/host status = %d, want %d: %s", resp.StatusCode, http.StatusOK, body)
	}
	var info clientcontrol.HostInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		t.Fatalf("decode host info: %v", err)
	}
	return info
}

func getAndroidTransportProfiles(t *testing.T, baseURL string) []clientcontrol.TransportProfileStatus {
	t.Helper()

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(baseURL + "/v1/transport-profiles")
	if err != nil {
		t.Fatalf("GET /v1/transport-profiles error = %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		t.Fatalf("GET /v1/transport-profiles status = %d, want %d: %s", resp.StatusCode, http.StatusOK, body)
	}
	var profiles []clientcontrol.TransportProfileStatus
	if err := json.NewDecoder(resp.Body).Decode(&profiles); err != nil {
		t.Fatalf("decode transport profiles: %v", err)
	}
	return profiles
}

func startPlatformTunnel(
	t *testing.T,
	baseURL string,
	req clientcontrol.PlatformTunnelStartRequest,
) clientcontrol.PlatformTunnelStartResult {
	t.Helper()

	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/platform-tunnels/start", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/platform-tunnels/start error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/start status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var result clientcontrol.PlatformTunnelStartResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode platform tunnel start result: %v", err)
	}
	return result
}

func resumePlatformTunnel(
	t *testing.T,
	baseURL string,
	req clientcontrol.PlatformTunnelResumeRequest,
) clientcontrol.PlatformTunnelStartResult {
	t.Helper()

	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/platform-tunnels/resume", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/platform-tunnels/resume error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/resume status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var result clientcontrol.PlatformTunnelStartResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode platform tunnel resume result: %v", err)
	}
	return result
}

func stopPlatformTunnel(
	t *testing.T,
	baseURL string,
	req clientcontrol.PlatformTunnelStopRequest,
) clientcontrol.PlatformTunnelStopResult {
	t.Helper()

	body, err := json.Marshal(req)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/platform-tunnels/stop", "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("POST /v1/platform-tunnels/stop error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/platform-tunnels/stop status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var result clientcontrol.PlatformTunnelStopResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		t.Fatalf("decode platform tunnel stop result: %v", err)
	}
	return result
}

func assertAndroidVPNExecutionPlan(t *testing.T, plan *clientcontrol.RuntimeExecutionPlan) {
	t.Helper()

	if plan == nil {
		t.Fatal("execution plan = nil, want android_vpn_service plan")
	}
	if plan.EngineFamily != clientcontrol.RuntimeEngineFamilyWireGuardNative {
		t.Fatalf("execution plan engine_family = %q, want %q", plan.EngineFamily, clientcontrol.RuntimeEngineFamilyWireGuardNative)
	}
	if plan.HostAdapter != clientcontrol.RuntimeHostAdapterAndroidVPNService {
		t.Fatalf("execution plan host_adapter = %q, want %q", plan.HostAdapter, clientcontrol.RuntimeHostAdapterAndroidVPNService)
	}
}
