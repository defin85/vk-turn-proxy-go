package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

type fakeAdapter struct {
	name       string
	resolution provider.Resolution
	err        error
}

func (f fakeAdapter) Name() string { return f.name }

func (f fakeAdapter) Resolve(context.Context, string) (provider.Resolution, error) {
	return f.resolution, f.err
}

func TestRunProbeWritesArtifactOnSuccess(t *testing.T) {
	outputDir := t.TempDir()
	artifact := &provider.ProbeArtifact{
		Provider:         "vk",
		ResolutionMethod: "staged_http",
		Stages: []provider.ProbeArtifactStage{
			{Name: "a", EndpointID: "a"},
			{Name: "b", EndpointID: "b"},
		},
		Outcome: provider.ProbeArtifactOutcome{
			ResultKind: "resolution",
			Resolution: &provider.ProbeArtifactResolution{
				UsernameRedacted: "<redacted:turn-username>",
				PasswordRedacted: "<redacted:turn-password>",
				Address:          "turn.example.test:3478",
			},
		},
	}
	registry := provider.NewRegistry(fakeAdapter{
		name: "vk",
		resolution: provider.Resolution{
			Credentials: provider.Credentials{
				Address: "turn.example.test:3478",
			},
			Artifact: artifact,
		},
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runProbe(context.Background(), &stdout, &stderr, []string{
		"-provider", "vk",
		"-link", "https://vk.com/call/join/test-token",
		"-output-dir", outputDir,
	}, registry)
	if code != 0 {
		t.Fatalf("runProbe() code = %d, stderr=%s", code, stderr.String())
	}

	artifactPath := filepath.Join(outputDir, "vk", "probe-artifact.json")
	data, err := os.ReadFile(artifactPath)
	if err != nil {
		t.Fatalf("read artifact: %v", err)
	}

	var saved provider.ProbeArtifact
	if err := json.Unmarshal(data, &saved); err != nil {
		t.Fatalf("decode artifact: %v", err)
	}
	if len(saved.Stages) != 2 {
		t.Fatalf("unexpected stage count %d", len(saved.Stages))
	}
	if !strings.Contains(stdout.String(), "artifact="+artifactPath) {
		t.Fatalf("stdout missing artifact path: %s", stdout.String())
	}
	if !strings.Contains(stdout.String(), "stages=2") {
		t.Fatalf("stdout missing stage count: %s", stdout.String())
	}
}

func TestRunProbeWritesArtifactOnFailure(t *testing.T) {
	outputDir := t.TempDir()
	artifact := &provider.ProbeArtifact{
		Provider:         "vk",
		ResolutionMethod: "staged_http",
		Stages: []provider.ProbeArtifactStage{
			{Name: "ok_join_conversation_by_link", EndpointID: "ok_join_conversation_by_link"},
		},
		Outcome: provider.ProbeArtifactOutcome{
			ResultKind: "provider_error",
			ProviderError: &provider.ProbeArtifactProviderError{
				Stage: "ok_join_conversation_by_link",
				Code:  "missing_turn_url",
			},
		},
	}
	registry := provider.NewRegistry(fakeAdapter{
		name: "vk",
		err: &provider.ArtifactError{
			Err:           errors.New("vk stage ok_join_conversation_by_link [missing_turn_url]"),
			ProbeArtifact: artifact,
		},
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runProbe(context.Background(), &stdout, &stderr, []string{
		"-provider", "vk",
		"-link", "https://vk.com/call/join/test-token",
		"-output-dir", outputDir,
	}, registry)
	if code != 1 {
		t.Fatalf("runProbe() code = %d, stderr=%s", code, stderr.String())
	}

	artifactPath := filepath.Join(outputDir, "vk", "probe-artifact.json")
	if _, err := os.Stat(artifactPath); err != nil {
		t.Fatalf("artifact not written: %v", err)
	}
	if !strings.Contains(stderr.String(), "artifact_path="+artifactPath) {
		t.Fatalf("stderr missing artifact path: %s", stderr.String())
	}
	if !strings.Contains(stderr.String(), "probe failed:") {
		t.Fatalf("stderr missing failure summary: %s", stderr.String())
	}
}
