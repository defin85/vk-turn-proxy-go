package androidembeddedhost

import (
	"bytes"
	"encoding/json"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/pkg/clientcontrol"
)

func TestManagerEnsureStartedServesClientControlHost(t *testing.T) {
	t.Parallel()

	manager := New()
	baseURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("EnsureStarted() error = %v", err)
	}
	t.Cleanup(func() {
		if err := manager.Stop(); err != nil {
			t.Fatalf("Stop() error = %v", err)
		}
	})

	if !strings.HasPrefix(baseURL, "http://127.0.0.1:") {
		t.Fatalf("baseURL = %q, want loopback HTTP URL", baseURL)
	}

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
	if info.ContractVersion != clientcontrol.ContractVersion {
		t.Fatalf("contract_version = %q, want %q", info.ContractVersion, clientcontrol.ContractVersion)
	}
	if info.Build.Role != "android_embedded_host" {
		t.Fatalf("build.role = %q, want android_embedded_host", info.Build.Role)
	}
}

func TestManagerEnsureStartedIsIdempotent(t *testing.T) {
	t.Parallel()

	manager := New()
	baseURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("EnsureStarted() error = %v", err)
	}
	t.Cleanup(func() {
		if err := manager.Stop(); err != nil {
			t.Fatalf("Stop() error = %v", err)
		}
	})

	nextURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("second EnsureStarted() error = %v", err)
	}
	if nextURL != baseURL {
		t.Fatalf("second EnsureStarted() = %q, want %q", nextURL, baseURL)
	}
}

func TestManagerNegotiateSupportsMobileHostBridgeContract(t *testing.T) {
	t.Parallel()

	manager := New()
	baseURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("EnsureStarted() error = %v", err)
	}
	t.Cleanup(func() {
		if err := manager.Stop(); err != nil {
			t.Fatalf("Stop() error = %v", err)
		}
	})

	payload, err := json.Marshal(clientcontrol.NegotiateRequest{
		SupportedVersions: []string{clientcontrol.ContractVersion},
		RequiredCapabilities: []clientcontrol.Capability{
			clientcontrol.CapabilityMobileHostBridge,
			clientcontrol.CapabilityProfiles,
			clientcontrol.CapabilitySessions,
			clientcontrol.CapabilityChallenges,
			clientcontrol.CapabilityDiagnostics,
			clientcontrol.CapabilityEventStream,
		},
	})
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Post(baseURL+"/v1/negotiate", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("POST /v1/negotiate error = %v", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/negotiate status = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var info clientcontrol.HostInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		t.Fatalf("decode negotiated host info: %v", err)
	}
	if info.Build.Role != "android_embedded_host" {
		t.Fatalf("build.role = %q, want android_embedded_host", info.Build.Role)
	}
	if !containsCapability(info.Capabilities, clientcontrol.CapabilityMobileHostBridge) {
		t.Fatalf("capabilities = %v, want mobile_host_bridge", info.Capabilities)
	}
}

func TestManagerProfilesRoundTripThroughLoopbackHTTP(t *testing.T) {
	t.Parallel()

	manager := New()
	baseURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("EnsureStarted() error = %v", err)
	}
	t.Cleanup(func() {
		if err := manager.Stop(); err != nil {
			t.Fatalf("Stop() error = %v", err)
		}
	})

	profile := clientcontrol.Profile{
		ID:   "profile-1",
		Name: "vk live",
		Spec: clientcontrol.ProfileSpec{
			Provider:            "vk",
			Link:                "https://vk.com/call/join/test-token",
			ListenAddr:          "127.0.0.1:9006",
			PeerAddr:            "176.109.104.105:38218",
			InteractiveProvider: true,
		},
	}
	payload, err := json.Marshal(profile)
	if err != nil {
		t.Fatalf("Marshal() error = %v", err)
	}

	client := &http.Client{Timeout: 5 * time.Second}
	upsertResp, err := client.Post(baseURL+"/v1/profiles", "application/json", bytes.NewReader(payload))
	if err != nil {
		t.Fatalf("POST /v1/profiles error = %v", err)
	}
	defer upsertResp.Body.Close()

	if upsertResp.StatusCode != http.StatusOK {
		t.Fatalf("POST /v1/profiles status = %d, want %d", upsertResp.StatusCode, http.StatusOK)
	}

	listResp, err := client.Get(baseURL + "/v1/profiles")
	if err != nil {
		t.Fatalf("GET /v1/profiles error = %v", err)
	}
	defer listResp.Body.Close()

	if listResp.StatusCode != http.StatusOK {
		t.Fatalf("GET /v1/profiles status = %d, want %d", listResp.StatusCode, http.StatusOK)
	}

	var profiles []clientcontrol.Profile
	if err := json.NewDecoder(listResp.Body).Decode(&profiles); err != nil {
		t.Fatalf("decode profiles: %v", err)
	}
	if len(profiles) != 1 {
		t.Fatalf("profiles len = %d, want 1", len(profiles))
	}
	if profiles[0].ID != profile.ID {
		t.Fatalf("profile id = %q, want %q", profiles[0].ID, profile.ID)
	}
}

func TestManagerStopAllowsRestart(t *testing.T) {
	t.Parallel()

	manager := New()
	baseURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("EnsureStarted() error = %v", err)
	}
	if err := manager.Stop(); err != nil {
		t.Fatalf("Stop() error = %v", err)
	}

	restartedURL, err := manager.EnsureStarted()
	if err != nil {
		t.Fatalf("restart EnsureStarted() error = %v", err)
	}
	t.Cleanup(func() {
		if err := manager.Stop(); err != nil {
			t.Fatalf("final Stop() error = %v", err)
		}
	})

	if restartedURL == "" {
		t.Fatal("restart EnsureStarted() returned empty URL")
	}
	if restartedURL == baseURL {
		t.Fatalf("restart EnsureStarted() = %q, want a new loopback URL after Stop()", restartedURL)
	}
}

func containsCapability(caps []clientcontrol.Capability, want clientcontrol.Capability) bool {
	for _, cap := range caps {
		if cap == want {
			return true
		}
	}
	return false
}
