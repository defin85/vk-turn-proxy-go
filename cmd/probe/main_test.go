package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
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
	resolve    func(context.Context, string) (provider.Resolution, error)
}

func (f fakeAdapter) Name() string { return f.name }

func (f fakeAdapter) Resolve(ctx context.Context, link string) (provider.Resolution, error) {
	if f.resolve != nil {
		return f.resolve(ctx, link)
	}
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
	code := runProbe(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
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
	code := runProbe(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
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

func TestListProvidersIncludesGenericTurn(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer

	code := runProbe(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{"-list-providers"}, newRegistry())
	if code != 0 {
		t.Fatalf("runProbe() code = %d, stderr=%s", code, stderr.String())
	}

	if got := stdout.String(); got != "generic-turn\nvk\n" {
		t.Fatalf("unexpected providers list %q", got)
	}
}

func TestRunProbeGenericTurnWritesRedactedArtifact(t *testing.T) {
	outputDir := t.TempDir()
	link := "generic-turn://alice:s3cret@turn.example.test:3478"

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runProbe(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", link,
		"-output-dir", outputDir,
	}, newRegistry())
	if code != 0 {
		t.Fatalf("runProbe() code = %d, stderr=%s", code, stderr.String())
	}

	artifactPath := filepath.Join(outputDir, "generic-turn", "probe-artifact.json")
	data, err := os.ReadFile(artifactPath)
	if err != nil {
		t.Fatalf("read artifact: %v", err)
	}
	if strings.Contains(string(data), "alice") {
		t.Fatalf("artifact leaked username: %s", data)
	}
	if strings.Contains(string(data), "s3cret") {
		t.Fatalf("artifact leaked password: %s", data)
	}
	if strings.Contains(string(data), link) {
		t.Fatalf("artifact leaked raw link: %s", data)
	}

	var saved provider.ProbeArtifact
	if err := json.Unmarshal(data, &saved); err != nil {
		t.Fatalf("decode artifact: %v", err)
	}
	if saved.Provider != "generic-turn" {
		t.Fatalf("unexpected provider %q", saved.Provider)
	}
	if saved.Input.LinkRedacted != "generic-turn://<redacted:turn-username>:<redacted:turn-password>@turn.example.test:3478" {
		t.Fatalf("unexpected redacted link %q", saved.Input.LinkRedacted)
	}
	if saved.Outcome.Resolution == nil || saved.Outcome.Resolution.Address != "turn.example.test:3478" {
		t.Fatalf("unexpected resolution outcome %#v", saved.Outcome.Resolution)
	}
	if len(saved.Stages) != 1 {
		t.Fatalf("unexpected stage count %d", len(saved.Stages))
	}
	if !strings.Contains(stdout.String(), "turn_addr=turn.example.test:3478") {
		t.Fatalf("stdout missing normalized turn addr: %s", stdout.String())
	}
	if !strings.Contains(stdout.String(), "stages=1") {
		t.Fatalf("stdout missing stage count: %s", stdout.String())
	}
}

type fakeChallenge struct {
	provider string
	stage    string
	kind     string
	prompt   string
	openURL  string
}

func (f fakeChallenge) ProviderName() string { return f.provider }
func (f fakeChallenge) StageName() string    { return f.stage }
func (f fakeChallenge) Kind() string         { return f.kind }
func (f fakeChallenge) Prompt() string       { return f.prompt }
func (f fakeChallenge) OpenURL() string      { return f.openURL }
func (f fakeChallenge) CookieURLs() []string { return []string{"https://api.vk.ru/"} }

type fakeInteractiveProviderHandler struct {
	handle     func(context.Context, provider.InteractiveChallenge) error
	continueFn func(context.Context, provider.InteractiveChallenge) (*provider.BrowserContinuation, error)
}

func (h fakeInteractiveProviderHandler) Handle(ctx context.Context, challenge provider.InteractiveChallenge) error {
	if h.handle != nil {
		return h.handle(ctx, challenge)
	}
	return nil
}

func (h fakeInteractiveProviderHandler) Continue(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
	if h.continueFn != nil {
		return h.continueFn(ctx, challenge)
	}
	return &provider.BrowserContinuation{
		Cookies: []*http.Cookie{{Name: "remixsid", Value: "secret", Domain: ".vk.ru", Path: "/"}},
	}, nil
}

func TestRunProbeInteractiveProviderChallenge(t *testing.T) {
	outputDir := t.TempDir()
	calledContinue := false
	previousFactory := newInteractiveProviderHandler
	newInteractiveProviderHandler = func(stdin io.Reader, stderr io.Writer) interactiveProviderHandler {
		return fakeInteractiveProviderHandler{
			continueFn: func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
				calledContinue = true
				return &provider.BrowserContinuation{
					Cookies: []*http.Cookie{{Name: "remixsid", Value: "secret", Domain: ".vk.ru", Path: "/"}},
				}, nil
			},
		}
	}
	t.Cleanup(func() {
		newInteractiveProviderHandler = previousFactory
	})

	artifact := &provider.ProbeArtifact{
		Provider: "vk",
		Stages: []provider.ProbeArtifactStage{
			{Name: "vk_calls_get_anonymous_token", EndpointID: "vk_calls_get_anonymous_token"},
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
		resolve: func(ctx context.Context, _ string) (provider.Resolution, error) {
			handler := provider.BrowserContinuationHandlerFromContext(ctx)
			if handler == nil {
				t.Fatal("browser continuation handler is required")
			}
			if _, err := handler.Continue(ctx, fakeChallenge{
				provider: "vk",
				stage:    "vk_calls_get_anonymous_token",
				kind:     "captcha",
				prompt:   "complete captcha",
				openURL:  "https://example.test/challenge",
			}); err != nil {
				return provider.Resolution{}, err
			}
			return provider.Resolution{
				Credentials: provider.Credentials{
					Address: "turn.example.test:3478",
				},
				Artifact: artifact,
			}, nil
		},
	})

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runProbe(context.Background(), strings.NewReader("continue\n"), &stdout, &stderr, []string{
		"-provider", "vk",
		"-link", "https://vk.com/call/join/test-token",
		"-output-dir", outputDir,
		"-interactive-provider",
	}, registry)
	if code != 0 {
		t.Fatalf("runProbe() code = %d, stderr=%s stdout=%s", code, stderr.String(), stdout.String())
	}
	if !calledContinue {
		t.Fatal("expected browser continuation handler to be called")
	}
}
