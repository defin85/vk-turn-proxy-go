package vkcompat_test

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	vkprovider "github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
)

type providerFixture struct {
	ScenarioID string                  `json:"scenario_id"`
	Provider   string                  `json:"provider"`
	Input      providerFixtureInput    `json:"input"`
	Stages     []providerFixtureStage  `json:"stages"`
	Expected   providerFixtureExpected `json:"expected"`
}

type providerFixtureInput struct {
	InputFamily                 string `json:"input_family"`
	LinkRedacted                string `json:"link_redacted"`
	InviteURLRedacted           string `json:"invite_url_redacted"`
	NormalizedJoinTokenRedacted string `json:"normalized_join_token_redacted"`
}

type providerFixtureStage struct {
	Name       string `json:"name"`
	EndpointID string `json:"endpoint_id"`
	Request    struct {
		Method   string   `json:"method"`
		FormKeys []string `json:"form_keys"`
	} `json:"request"`
	Response struct {
		StatusCode int            `json:"status_code"`
		Body       map[string]any `json:"body"`
	} `json:"response"`
}

type providerFixtureExpected struct {
	ResultKind string `json:"result_kind"`
	Resolution struct {
		Username string `json:"username_redacted"`
		Password string `json:"password_redacted"`
		Address  string `json:"address"`
	} `json:"resolution"`
	ProviderError struct {
		Stage string `json:"stage"`
		Code  string `json:"code"`
	} `json:"provider_error"`
}

func TestProviderFixtureAssets(t *testing.T) {
	matches, err := filepath.Glob(filepath.Join("fixtures", "*.json"))
	if err != nil {
		t.Fatalf("glob fixtures: %v", err)
	}
	if len(matches) == 0 {
		t.Fatal("expected provider fixtures")
	}

	expectedFixtures := map[string]bool{
		"vk_call_authenticated_success_v1":                       false,
		"vk_call_authenticated_transport_missing_v1":             false,
		"vk_call_debug_browser_continuation_failed_v1":           false,
		"vk_call_debug_captcha_required_v1":                      false,
		"vk_call_debug_captcha_resume_success_v1":                false,
		"vk_call_debug_live_browser_post_preview_unsupported_v1": false,
		"vk_call_debug_live_browser_preview_only_v1":             false,
		"vk_call_debug_stage4_missing_turn_url_v1":               false,
		"vk_call_debug_success_v1":                               false,
	}

	for _, path := range matches {
		fixture := loadProviderFixture(t, path)
		if _, ok := expectedFixtures[fixture.ScenarioID]; ok {
			expectedFixtures[fixture.ScenarioID] = true
		}
		if fixture.Provider != "vk" {
			t.Fatalf("%s: provider = %q, want vk", path, fixture.Provider)
		}
		wantScenarioID := strings.TrimSuffix(filepath.Base(path), ".json")
		if fixture.ScenarioID != wantScenarioID {
			t.Fatalf("%s: scenario_id = %q, want %q", path, fixture.ScenarioID, wantScenarioID)
		}
		switch fixture.Input.InputFamily {
		case "invite":
			if fixture.Input.InviteURLRedacted == "" || fixture.Input.NormalizedJoinTokenRedacted == "" {
				t.Fatalf("%s: invite input family requires redacted invite fields", path)
			}
		case "authenticated_root":
			if fixture.Input.LinkRedacted != "https://calls.vk.com/" {
				t.Fatalf("%s: authenticated root link = %q, want https://calls.vk.com/", path, fixture.Input.LinkRedacted)
			}
		default:
			t.Fatalf("%s: unsupported input_family %q", path, fixture.Input.InputFamily)
		}
	}

	for scenarioID, seen := range expectedFixtures {
		if !seen {
			t.Fatalf("missing provider fixture for %s", scenarioID)
		}
	}
}

func TestAuthenticatedFixtureReplay(t *testing.T) {
	fixtures := []string{
		"vk_call_authenticated_success_v1.json",
		"vk_call_authenticated_transport_missing_v1.json",
	}

	for _, name := range fixtures {
		name := name
		t.Run(strings.TrimSuffix(name, ".json"), func(t *testing.T) {
			fixture := loadProviderFixture(t, filepath.Join("fixtures", name))
			adapter := vkprovider.NewWithHTTPDoer(unexpectedReplayHTTPDoer{t: t})

			ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
				results := make([]provider.BrowserStageResult, 0, len(fixture.Stages))
				for _, stage := range fixture.Stages {
					results = append(results, provider.BrowserStageResult{
						Stage:      stage.Name,
						Method:     stage.Request.Method,
						URL:        authenticatedObservedStageURL(stage.EndpointID),
						FormKeys:   append([]string(nil), stage.Request.FormKeys...),
						StatusCode: stage.Response.StatusCode,
						Body:       stage.Response.Body,
					})
				}
				return &provider.BrowserContinuation{StageResults: results}, nil
			}))

			resolution, err := adapter.Resolve(ctx, fixture.Input.LinkRedacted)
			switch fixture.Expected.ResultKind {
			case "resolution":
				if err != nil {
					t.Fatalf("Resolve() error = %v", err)
				}
				if resolution.Credentials.Username != fixture.Expected.Resolution.Username {
					t.Fatalf("username = %q, want %q", resolution.Credentials.Username, fixture.Expected.Resolution.Username)
				}
				if resolution.Credentials.Password != fixture.Expected.Resolution.Password {
					t.Fatalf("password = %q, want %q", resolution.Credentials.Password, fixture.Expected.Resolution.Password)
				}
				if resolution.Credentials.Address != fixture.Expected.Resolution.Address {
					t.Fatalf("address = %q, want %q", resolution.Credentials.Address, fixture.Expected.Resolution.Address)
				}
			case "provider_error":
				if err == nil {
					t.Fatal("Resolve() expected error")
				}
				var carrier provider.ArtifactCarrier
				if !errors.As(err, &carrier) {
					t.Fatalf("expected artifact carrier, got %T", err)
				}
				artifact := carrier.Artifact()
				if artifact == nil || artifact.Outcome.ProviderError == nil {
					t.Fatalf("expected provider error artifact, got %#v", artifact)
				}
				if artifact.Outcome.ProviderError.Stage != fixture.Expected.ProviderError.Stage {
					t.Fatalf("artifact stage = %q, want %q", artifact.Outcome.ProviderError.Stage, fixture.Expected.ProviderError.Stage)
				}
				if artifact.Outcome.ProviderError.Code != fixture.Expected.ProviderError.Code {
					t.Fatalf("artifact code = %q, want %q", artifact.Outcome.ProviderError.Code, fixture.Expected.ProviderError.Code)
				}
			default:
				t.Fatalf("unsupported expected result_kind %q", fixture.Expected.ResultKind)
			}
		})
	}
}

type unexpectedReplayHTTPDoer struct {
	t *testing.T
}

func (d unexpectedReplayHTTPDoer) Do(_ *http.Request) (*http.Response, error) {
	d.t.Helper()
	d.t.Fatal("authenticated compatibility replay must not perform direct HTTP stages")
	return nil, nil
}

func loadProviderFixture(t *testing.T, path string) providerFixture {
	t.Helper()

	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read fixture %s: %v", path, err)
	}

	var fixture providerFixture
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatalf("decode fixture %s: %v", path, err)
	}

	return fixture
}

func authenticatedObservedStageURL(endpointID string) string {
	switch endpointID {
	case "ok_anonym_login", "ok_start_conversation_create_join_link":
		return "https://calls.okcdn.ru/fb.do"
	default:
		return ""
	}
}
