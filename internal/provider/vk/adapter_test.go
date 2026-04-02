package vk

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"testing"
)

type fixture struct {
	ScenarioID string `json:"scenario_id"`
	Stages     []struct {
		EndpointID string `json:"endpoint_id"`
		Request    struct {
			FormKeys []string `json:"form_keys"`
		} `json:"request"`
		Response struct {
			StatusCode int            `json:"status_code"`
			Body       map[string]any `json:"body"`
		} `json:"response"`
	} `json:"stages"`
	Expected struct {
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
	} `json:"expected"`
}

type fixtureDoer struct {
	t      *testing.T
	stages []struct {
		EndpointID string `json:"endpoint_id"`
		Request    struct {
			FormKeys []string `json:"form_keys"`
		} `json:"request"`
		Response struct {
			StatusCode int            `json:"status_code"`
			Body       map[string]any `json:"body"`
		} `json:"response"`
	}
	calls int
}

func (d *fixtureDoer) Do(request *http.Request) (*http.Response, error) {
	d.t.Helper()

	if d.calls >= len(d.stages) {
		d.t.Fatalf("unexpected extra HTTP call to %s", request.URL.String())
	}

	stage := d.stages[d.calls]
	d.calls++

	if request.Method != http.MethodPost {
		d.t.Fatalf("unexpected method for stage %s: %s", stage.EndpointID, request.Method)
	}
	if got, want := request.URL.String(), endpointURL(stage.EndpointID); got != want {
		d.t.Fatalf("unexpected URL for stage %s: got %s want %s", stage.EndpointID, got, want)
	}
	if err := request.ParseForm(); err != nil {
		d.t.Fatalf("parse form for stage %s: %v", stage.EndpointID, err)
	}
	for _, key := range stage.Request.FormKeys {
		if _, ok := request.PostForm[key]; !ok {
			d.t.Fatalf("stage %s missing form key %q", stage.EndpointID, key)
		}
	}

	body, err := json.Marshal(stage.Response.Body)
	if err != nil {
		d.t.Fatalf("marshal response body: %v", err)
	}

	return &http.Response{
		StatusCode: stage.Response.StatusCode,
		Status:     http.StatusText(stage.Response.StatusCode),
		Body:       io.NopCloser(bytes.NewReader(body)),
		Header:     make(http.Header),
	}, nil
}

func TestResolveUsesStagedVKFlow(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_success_v1.json")
	doer := &fixtureDoer{t: t, stages: fixture.Stages}
	adapter := NewWithHTTPDoer(doer)

	resolution, err := adapter.Resolve(context.Background(), "https://vk.com/call/join/test-token?foo=bar")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}

	if resolution.Credentials.Username != fixture.Expected.Resolution.Username {
		t.Fatalf("unexpected username %q", resolution.Credentials.Username)
	}
	if resolution.Credentials.Password != fixture.Expected.Resolution.Password {
		t.Fatalf("unexpected password %q", resolution.Credentials.Password)
	}
	if resolution.Credentials.Address != fixture.Expected.Resolution.Address {
		t.Fatalf("unexpected address %q", resolution.Credentials.Address)
	}
	if got := resolution.Metadata["resolution_method"]; got != "staged_http" {
		t.Fatalf("unexpected resolution method %q", got)
	}
	if doer.calls != len(fixture.Stages) {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}
}

func TestResolveRejectsMalformedVKLinkBeforeNetwork(t *testing.T) {
	doer := &fixtureDoer{t: t}
	adapter := NewWithHTTPDoer(doer)

	_, err := adapter.Resolve(context.Background(), "https://vk.com/not-a-call/join/test-token")
	if err == nil {
		t.Fatal("Resolve() expected error for malformed VK link")
	}
	if doer.calls != 0 {
		t.Fatalf("expected no HTTP calls, got %d", doer.calls)
	}
}

func TestResolveReturnsExplicitStageErrorForMissingTurnURL(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_stage4_missing_turn_url_v1.json")
	doer := &fixtureDoer{t: t, stages: fixture.Stages}
	adapter := NewWithHTTPDoer(doer)

	_, err := adapter.Resolve(context.Background(), "test-token")
	if err == nil {
		t.Fatal("Resolve() expected error")
	}

	var stageErr *stageError
	if !errors.As(err, &stageErr) {
		t.Fatalf("expected stageError, got %T", err)
	}
	if stageErr.stage != fixture.Expected.ProviderError.Stage {
		t.Fatalf("unexpected stage %q", stageErr.stage)
	}
	if stageErr.code != fixture.Expected.ProviderError.Code {
		t.Fatalf("unexpected code %q", stageErr.code)
	}
	if doer.calls != len(fixture.Stages) {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}
}

func loadFixture(t *testing.T, name string) fixture {
	t.Helper()

	path := filepath.Join("..", "..", "..", "test", "compatibility", "vk", "fixtures", name)
	data, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read fixture %s: %v", name, err)
	}

	var fixture fixture
	if err := json.Unmarshal(data, &fixture); err != nil {
		t.Fatalf("decode fixture %s: %v", name, err)
	}

	return fixture
}

func endpointURL(endpointID string) string {
	switch endpointID {
	case stageLoginAnonymToken:
		return loginAnonymTokenURL
	case stageGetAnonymousToken:
		return getAnonymousTokenURL
	case stageOKAnonymLogin, stageJoinConversationByURL:
		return okAPIURL
	default:
		return ""
	}
}
