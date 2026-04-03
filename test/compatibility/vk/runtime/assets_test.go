package vkruntime_test

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

type evidenceAsset struct {
	ScenarioID string          `json:"scenario_id"`
	Provider   string          `json:"provider"`
	Kind       string          `json:"kind"`
	Source     evidenceSource  `json:"source"`
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

			validateEvidenceAsset(t, path, asset)
		})
	}
}

func validateEvidenceAsset(t *testing.T, path string, asset evidenceAsset) {
	t.Helper()

	if asset.ScenarioID == "" {
		t.Fatalf("%s: scenario_id is required", path)
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
	if asset.Source.CapturedAt == "" || asset.Source.LegacyReference == "" || asset.Source.RewriteReference == "" {
		t.Fatalf("%s: source fields must be populated", path)
	}

	if asset.Slice.Connections != 1 || !asset.Slice.DTLS {
		t.Fatalf("%s: unsupported slice %+v", path, asset.Slice)
	}
	if asset.Slice.Mode != "udp" && asset.Slice.Mode != "auto" {
		t.Fatalf("%s: unsupported mode %q", path, asset.Slice.Mode)
	}
	if asset.Slice.BindInterface != "" {
		t.Fatalf("%s: bind_interface must be empty, got %q", path, asset.Slice.BindInterface)
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
}
