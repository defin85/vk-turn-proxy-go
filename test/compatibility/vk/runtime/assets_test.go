package vkruntime_test

import (
	"encoding/json"
	"net"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

type evidenceAsset struct {
	ScenarioID string          `json:"scenario_id"`
	Provider   string          `json:"provider"`
	Kind       string          `json:"kind"`
	Source     evidenceSource  `json:"source"`
	Replay     evidenceReplay  `json:"replay"`
	Slice      evidenceSlice   `json:"slice"`
	Input      evidenceInput   `json:"input"`
	Legacy     evidenceOutcome `json:"legacy"`
	Rewrite    evidenceOutcome `json:"rewrite"`
	Deviations []string        `json:"deviations"`
}

type evidenceSource struct {
	Kind             string `json:"kind"`
	CapturedAt       string `json:"captured_at"`
	LegacyReference  string `json:"legacy_reference"`
	RewriteReference string `json:"rewrite_reference"`
}

type evidenceReplay struct {
	ProviderFixture  string `json:"provider_fixture"`
	ExpectTURNBaseIP string `json:"expect_turn_base_ip"`
}

type evidenceSlice struct {
	Connections   int    `json:"connections"`
	DTLS          bool   `json:"dtls"`
	Mode          string `json:"mode"`
	BindInterface string `json:"bind_interface"`
}

type evidenceInput struct {
	InviteRedacted   string `json:"invite_redacted"`
	PeerAddrRedacted string `json:"peer_addr_redacted"`
	TURNOverride     string `json:"turn_override"`
	PortOverride     string `json:"port_override"`
}

type evidenceOutcome struct {
	Result              string   `json:"result"`
	ExitCode            int      `json:"exit_code"`
	ErrorStage          string   `json:"error_stage"`
	ForwardingRoundTrip bool     `json:"forwarding_round_trip"`
	Notes               []string `json:"notes"`
}

const (
	runtimePeerTurnlab         = "<runtime:turnlab-peer>"
	runtimePeerTurnlabUpstream = "<runtime:turnlab-upstream>"
	runtimePeerPlainUDP        = "<runtime:plain-udp-peer>"
	runtimeTurnHost            = "<runtime:turnlab-host>"
	runtimeTurnPort            = "<runtime:turnlab-port>"
	runtimeTurnTCPHost         = "<runtime:turnlab-tcp-host>"
	runtimeTurnTCPPort         = "<runtime:turnlab-tcp-port>"
)

func TestRuntimeEvidenceAssets(t *testing.T) {
	root := "."
	patterns := []string{
		filepath.Join(root, "examples", "*.json"),
		filepath.Join(root, "fixtures", "*.json"),
	}

	var files []string
	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			t.Fatalf("glob %s: %v", pattern, err)
		}
		files = append(files, matches...)
	}
	if len(files) == 0 {
		t.Fatal("expected at least example runtime evidence assets")
	}

	expectedFixtures := map[string]bool{
		"vk_runtime_success_v1":             false,
		"vk_runtime_failure_v1":             false,
		"vk_runtime_tcp_dtls_success_v1":    false,
		"vk_runtime_udp_plain_success_v1":   false,
		"vk_runtime_tcp_plain_success_v1":   false,
		"vk_runtime_bind_target_success_v1": false,
		"vk_runtime_auto_plain_success_v1":  false,
		"vk_runtime_auto_bind_success_v1":   false,
	}

	for _, path := range files {
		path := path
		t.Run(filepath.Base(path), func(t *testing.T) {
			data, err := os.ReadFile(path)
			if err != nil {
				t.Fatalf("read asset: %v", err)
			}

			var asset evidenceAsset
			if err := json.Unmarshal(data, &asset); err != nil {
				t.Fatalf("decode asset: %v", err)
			}

			kind := assetKindFromPath(t, path)
			if kind == "fixture" {
				if _, ok := expectedFixtures[asset.ScenarioID]; ok {
					expectedFixtures[asset.ScenarioID] = true
				}
			}

			validateEvidenceAsset(t, path, data, asset, kind)
		})
	}

	for scenarioID, seen := range expectedFixtures {
		if !seen {
			t.Fatalf("missing runtime evidence fixture for %s", scenarioID)
		}
	}
}

func assetKindFromPath(t *testing.T, path string) string {
	t.Helper()

	switch filepath.Base(filepath.Dir(path)) {
	case "examples":
		return "example"
	case "fixtures":
		return "fixture"
	default:
		t.Fatalf("%s: unsupported asset location", path)
		return ""
	}
}

func validateEvidenceAsset(t *testing.T, path string, raw []byte, asset evidenceAsset, kind string) {
	t.Helper()

	if asset.ScenarioID == "" {
		t.Fatalf("%s: scenario_id is required", path)
	}
	if want := scenarioIDFromFilename(path, kind); asset.ScenarioID != want {
		t.Fatalf("%s: scenario_id = %q, want %q from filename", path, asset.ScenarioID, want)
	}
	if asset.Provider != "vk" {
		t.Fatalf("%s: provider = %q, want vk", path, asset.Provider)
	}
	switch asset.Kind {
	case "runtime_success", "runtime_failure":
	default:
		t.Fatalf("%s: unsupported kind %q", path, asset.Kind)
	}

	switch asset.Source.Kind {
	case "template", "manual_live", "fixture_replay":
	default:
		t.Fatalf("%s: unsupported source.kind %q", path, asset.Source.Kind)
	}
	switch kind {
	case "example":
		if asset.Source.Kind != "template" {
			t.Fatalf("%s: example assets must use source.kind=template", path)
		}
		if !strings.Contains(string(raw), "<pending:") {
			t.Fatalf("%s: example asset must retain pending placeholders", path)
		}
	case "fixture":
		if asset.Source.Kind == "template" {
			t.Fatalf("%s: fixture assets must not use source.kind=template", path)
		}
		if strings.Contains(string(raw), "<pending:") {
			t.Fatalf("%s: fixture asset must not contain pending placeholders", path)
		}
	default:
		t.Fatalf("%s: unsupported validation kind %q", path, kind)
	}
	if asset.Source.CapturedAt == "" || asset.Source.LegacyReference == "" || asset.Source.RewriteReference == "" {
		t.Fatalf("%s: source fields must be populated", path)
	}
	if strings.TrimSpace(asset.Replay.ProviderFixture) == "" {
		t.Fatalf("%s: replay.provider_fixture is required", path)
	}
	validateReplayFixtureReference(t, path, asset.Replay.ProviderFixture)
	if kind == "fixture" || asset.Source.Kind == "fixture_replay" {
		validateReplayableInputs(t, path, asset.Input)
	}

	if asset.Slice.Connections != 1 {
		t.Fatalf("%s: unsupported slice %+v", path, asset.Slice)
	}
	switch asset.Slice.Mode {
	case "auto", "udp", "tcp":
	default:
		t.Fatalf("%s: unsupported mode %q", path, asset.Slice.Mode)
	}
	if kind == "fixture" && asset.Slice.BindInterface != "" && net.ParseIP(asset.Slice.BindInterface) == nil {
		t.Fatalf("%s: bind_interface must be a literal IP, got %q", path, asset.Slice.BindInterface)
	}
	if kind == "fixture" && asset.Slice.BindInterface != "" {
		if asset.Replay.ExpectTURNBaseIP != asset.Slice.BindInterface {
			t.Fatalf("%s: replay.expect_turn_base_ip = %q, want %q", path, asset.Replay.ExpectTURNBaseIP, asset.Slice.BindInterface)
		}
	}

	if !strings.Contains(asset.Input.InviteRedacted, "<redacted:") {
		t.Fatalf("%s: invite_redacted must stay redacted", path)
	}
	if strings.TrimSpace(asset.Input.PeerAddrRedacted) == "" {
		t.Fatalf("%s: peer_addr_redacted is required", path)
	}

	validateOutcome(t, path, "legacy", asset.Legacy)
	validateOutcome(t, path, "rewrite", asset.Rewrite)

	switch asset.Kind {
	case "runtime_success":
		if asset.Rewrite.Result != "success" || asset.Rewrite.ErrorStage != "" || !asset.Rewrite.ForwardingRoundTrip {
			t.Fatalf("%s: invalid rewrite success outcome %+v", path, asset.Rewrite)
		}
	case "runtime_failure":
		if asset.Rewrite.Result != "failure" || asset.Rewrite.ErrorStage == "" || asset.Rewrite.ForwardingRoundTrip {
			t.Fatalf("%s: invalid rewrite failure outcome %+v", path, asset.Rewrite)
		}
	}
}

func scenarioIDFromFilename(path string, kind string) string {
	base := filepath.Base(path)
	if kind == "example" {
		return strings.TrimSuffix(base, ".template.json")
	}

	return strings.TrimSuffix(base, ".json")
}

func validateOutcome(t *testing.T, path string, label string, outcome evidenceOutcome) {
	t.Helper()

	switch outcome.Result {
	case "success", "failure", "unsupported":
	default:
		t.Fatalf("%s: %s.result unsupported value %q", path, label, outcome.Result)
	}
	if outcome.ExitCode < 0 {
		t.Fatalf("%s: %s.exit_code must be non-negative", path, label)
	}
	if len(outcome.Notes) == 0 {
		t.Fatalf("%s: %s.notes must contain at least one entry", path, label)
	}
	if slices.Contains(outcome.Notes, "") {
		t.Fatalf("%s: %s.notes must not contain empty entries", path, label)
	}
}

func validateReplayFixtureReference(t *testing.T, path string, name string) {
	t.Helper()

	if filepath.Ext(name) != ".json" {
		t.Fatalf("%s: replay.provider_fixture must point to a .json file, got %q", path, name)
	}

	fixturePath := filepath.Join("..", "fixtures", name)
	if _, err := os.Stat(fixturePath); err != nil {
		t.Fatalf("%s: replay.provider_fixture %q is not available: %v", path, name, err)
	}
}

func validateReplayableInputs(t *testing.T, path string, input evidenceInput) {
	t.Helper()

	switch input.PeerAddrRedacted {
	case runtimePeerTurnlab, runtimePeerTurnlabUpstream, runtimePeerPlainUDP:
	default:
		t.Fatalf("%s: unsupported replay peer placeholder %q", path, input.PeerAddrRedacted)
	}

	if input.TURNOverride != runtimeTurnHost && input.TURNOverride != runtimeTurnTCPHost {
		t.Fatalf("%s: unsupported replay turn_override %q", path, input.TURNOverride)
	}
	if input.PortOverride != runtimeTurnPort && input.PortOverride != runtimeTurnTCPPort {
		t.Fatalf("%s: unsupported replay port_override %q", path, input.PortOverride)
	}
}
