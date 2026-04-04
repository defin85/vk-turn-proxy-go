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

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

type fixtureStage struct {
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

type fixture struct {
	ScenarioID string         `json:"scenario_id"`
	Stages     []fixtureStage `json:"stages"`
	Expected   struct {
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
	stages []fixtureStage
	calls  int
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

func TestResolveReturnsCaptchaRequiredWithoutInteractiveHandler(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_captcha_required_v1.json")
	doer := &fixtureDoer{t: t, stages: fixture.Stages}
	adapter := NewWithHTTPDoer(doer)

	_, err := adapter.Resolve(context.Background(), "test-token")
	if err == nil {
		t.Fatal("Resolve() expected error")
	}

	var captchaErr *CaptchaRequiredError
	if !errors.As(err, &captchaErr) {
		t.Fatalf("expected CaptchaRequiredError, got %T", err)
	}
	if captchaErr.Challenge() == nil {
		t.Fatal("captcha challenge is required")
	}
	if captchaErr.Challenge().StageName() != fixture.Expected.ProviderError.Stage {
		t.Fatalf("challenge stage = %q, want %q", captchaErr.Challenge().StageName(), fixture.Expected.ProviderError.Stage)
	}

	var stageErr *stageError
	if !errors.As(err, &stageErr) {
		t.Fatalf("expected stageError, got %T", err)
	}
	if stageErr.code != fixture.Expected.ProviderError.Code {
		t.Fatalf("unexpected code %q", stageErr.code)
	}
	if doer.calls != len(fixture.Stages) {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}

	var carrier provider.ArtifactCarrier
	if !errors.As(err, &carrier) {
		t.Fatalf("expected artifact carrier, got %T", err)
	}
	artifact := carrier.Artifact()
	if artifact == nil || artifact.Outcome.ProviderError == nil {
		t.Fatalf("expected provider error artifact, got %#v", artifact)
	}
	if artifact.Outcome.ProviderError.Code != fixture.Expected.ProviderError.Code {
		t.Fatalf("artifact code = %q, want %q", artifact.Outcome.ProviderError.Code, fixture.Expected.ProviderError.Code)
	}
}

func TestResolveContinuesAfterBrowserObservedChallenge(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_captcha_resume_success_v1.json")
	doer := &fixtureDoer{t: t, stages: []fixtureStage{
		fixture.Stages[0],
		fixture.Stages[1],
		fixture.Stages[3],
		fixture.Stages[4],
	}}
	adapter := NewWithHTTPDoer(doer)

	handlerCalls := 0
	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		handlerCalls++
		if challenge.ProviderName() != "vk" {
			t.Fatalf("challenge provider = %q", challenge.ProviderName())
		}
		if challenge.StageName() != stageGetAnonymousToken {
			t.Fatalf("challenge stage = %q", challenge.StageName())
		}
		if challenge.Kind() != "captcha" {
			t.Fatalf("challenge kind = %q", challenge.Kind())
		}
		if challenge.OpenURL() != "https://vk.com/call/join/test-token" {
			t.Fatalf("challenge open URL = %q", challenge.OpenURL())
		}
		stageChallenge, ok := challenge.(provider.BrowserObservedStageChallenge)
		if !ok {
			t.Fatalf("expected browser-observed stage challenge, got %T", challenge)
		}
		observations := stageChallenge.BrowserStageObservations()
		assertObservedStage(t, observations, stageGetAnonymousToken, "https://api.vk.com/method/calls.getAnonymousToken")
		assertObservedStage(t, observations, stageBrowserLoginAnonymTokenMessages, liveLoginAnonymTokenURL)
		assertObservedStage(t, observations, stageGetCallPreview, getCallPreviewURL)
		assertObservedStage(t, observations, stageOKAnonymLogin, okAPIURL)
		assertObservedStage(t, observations, stageJoinConversationByURL, okAPIURL)
		assertObservedStageExactFormValue(t, observations, stageJoinConversationByURL, "method", "vchat.joinConversationByLink")
		assertObservedStageAlternativeFormValue(t, observations, stageJoinConversationByURL, "joinLink", "test-token")
		assertObservedStageAlternativeFormValue(t, observations, stageJoinConversationByURL, "joinLink", "https://vk.com/call/join/test-token")
		return &provider.BrowserContinuation{
			StageResults: []provider.BrowserStageResult{
				{
					Stage:      fixture.Stages[2].Name,
					Method:     fixture.Stages[2].Request.Method,
					URL:        "https://api.vk.com/method/calls.getAnonymousToken?v=5.275&client_id=6287487",
					FormKeys:   []string{"access_token", "captcha_attempt", "captcha_key", "captcha_sid", "captcha_ts", "is_sound_captcha", "name", "success_token", "vk_join_link"},
					StatusCode: fixture.Stages[2].Response.StatusCode,
					Body:       fixture.Stages[2].Response.Body,
				},
			},
		}, nil
	}))

	resolution, err := adapter.Resolve(ctx, "https://vk.com/call/join/test-token")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if handlerCalls != 1 {
		t.Fatalf("interactive handler calls = %d, want 1", handlerCalls)
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
	if doer.calls != 4 {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}
	if resolution.Artifact == nil || len(resolution.Artifact.Stages) != len(fixture.Stages) {
		t.Fatalf("unexpected artifact stages %#v", resolution.Artifact)
	}
}

func TestResolvePrefersLegacyRepeatedStage2WhenLiveEvidenceDoesNotReachPreview(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_captcha_resume_success_v1.json")
	doer := &fixtureDoer{t: t, stages: []fixtureStage{
		fixture.Stages[0],
		fixture.Stages[1],
		fixture.Stages[3],
		fixture.Stages[4],
	}}
	adapter := NewWithHTTPDoer(doer)

	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		return &provider.BrowserContinuation{
			StageResults: []provider.BrowserStageResult{
				{
					Stage:      stageBrowserLoginAnonymTokenMessages,
					Method:     http.MethodPost,
					URL:        liveLoginAnonymTokenURL + "&app_id=6287487",
					FormKeys:   []string{"app_id", "client_id", "token_type", "version"},
					StatusCode: http.StatusOK,
					Body: map[string]any{
						"data": map[string]any{
							"access_token": "<redacted:vk-browser-access-token>",
						},
					},
				},
				{
					Stage:      fixture.Stages[2].Name,
					Method:     fixture.Stages[2].Request.Method,
					URL:        "https://api.vk.com/method/calls.getAnonymousToken?v=5.275&client_id=6287487",
					FormKeys:   []string{"access_token", "captcha_attempt", "captcha_key", "captcha_sid", "captcha_ts", "is_sound_captcha", "name", "success_token", "vk_join_link"},
					StatusCode: fixture.Stages[2].Response.StatusCode,
					Body:       fixture.Stages[2].Response.Body,
				},
			},
		}, nil
	}))

	resolution, err := adapter.Resolve(ctx, "https://vk.com/call/join/test-token")
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
	if resolution.Artifact == nil || len(resolution.Artifact.Stages) != len(fixture.Stages)+1 {
		t.Fatalf("unexpected artifact %#v", resolution.Artifact)
	}
	if resolution.Artifact.Stages[2].Name != stageBrowserLoginAnonymTokenMessages {
		t.Fatalf("expected preserved pre-preview live evidence, got %#v", resolution.Artifact.Stages)
	}
	if doer.calls != 4 {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}
}

func TestResolveFailsClosedOnLiveBrowserPreviewContour(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_live_browser_preview_only_v1.json")
	doer := &fixtureDoer{t: t, stages: fixture.Stages[:2]}
	adapter := NewWithHTTPDoer(doer)

	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		stageChallenge, ok := challenge.(provider.BrowserObservedStageChallenge)
		if !ok {
			t.Fatalf("expected browser-observed stage challenge, got %T", challenge)
		}
		observations := stageChallenge.BrowserStageObservations()
		assertObservedStage(t, observations, stageGetAnonymousToken, "https://api.vk.com/method/calls.getAnonymousToken")
		assertObservedStage(t, observations, stageBrowserLoginAnonymTokenMessages, liveLoginAnonymTokenURL)
		assertObservedStage(t, observations, stageGetCallPreview, getCallPreviewURL)
		assertObservedStage(t, observations, stageOKAnonymLogin, okAPIURL)
		assertObservedStage(t, observations, stageJoinConversationByURL, okAPIURL)

		return &provider.BrowserContinuation{
			StageResults: []provider.BrowserStageResult{
				{
					Stage:      fixture.Stages[2].Name,
					Method:     fixture.Stages[2].Request.Method,
					URL:        liveLoginAnonymTokenURL + "&app_id=6287487",
					FormKeys:   fixture.Stages[2].Request.FormKeys,
					StatusCode: fixture.Stages[2].Response.StatusCode,
					Body:       fixture.Stages[2].Response.Body,
				},
				{
					Stage:      fixture.Stages[3].Name,
					Method:     fixture.Stages[3].Request.Method,
					URL:        getCallPreviewURL + "?v=5.275&client_id=6287487",
					FormKeys:   fixture.Stages[3].Request.FormKeys,
					StatusCode: fixture.Stages[3].Response.StatusCode,
					Body:       fixture.Stages[3].Response.Body,
				},
			},
		}, nil
	}))

	_, err := adapter.Resolve(ctx, "https://vk.com/call/join/test-token")
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
	if doer.calls != 2 {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}

	var carrier provider.ArtifactCarrier
	if !errors.As(err, &carrier) {
		t.Fatalf("expected artifact carrier, got %T", err)
	}
	artifact := carrier.Artifact()
	if artifact == nil || len(artifact.Stages) != len(fixture.Stages) {
		t.Fatalf("unexpected artifact stages %#v", artifact)
	}
	if artifact.Outcome.ProviderError == nil {
		t.Fatalf("expected provider error outcome, got %#v", artifact.Outcome)
	}
	if artifact.Outcome.ProviderError.Stage != fixture.Expected.ProviderError.Stage {
		t.Fatalf("artifact stage = %q, want %q", artifact.Outcome.ProviderError.Stage, fixture.Expected.ProviderError.Stage)
	}
	if artifact.Outcome.ProviderError.Code != fixture.Expected.ProviderError.Code {
		t.Fatalf("artifact code = %q, want %q", artifact.Outcome.ProviderError.Code, fixture.Expected.ProviderError.Code)
	}
}

func TestResolveFailsClosedOnLiveBrowserPostPreviewUnsupportedContour(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_live_browser_post_preview_unsupported_v1.json")
	doer := &fixtureDoer{t: t, stages: fixture.Stages[:2]}
	adapter := NewWithHTTPDoer(doer)

	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		return &provider.BrowserContinuation{
			StageResults: []provider.BrowserStageResult{
				browserObservedResultFromFixture(fixture.Stages[2]),
				browserObservedResultFromFixture(fixture.Stages[3]),
				browserObservedResultFromFixture(fixture.Stages[4]),
			},
		}, nil
	}))

	_, err := adapter.Resolve(ctx, "https://vk.com/call/join/test-token")
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
	if doer.calls != 2 {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}

	var carrier provider.ArtifactCarrier
	if !errors.As(err, &carrier) {
		t.Fatalf("expected artifact carrier, got %T", err)
	}
	artifact := carrier.Artifact()
	if artifact == nil || len(artifact.Stages) != len(fixture.Stages) {
		t.Fatalf("unexpected artifact stages %#v", artifact)
	}
	if artifact.Stages[3].Name != stageGetCallPreview || artifact.Stages[3].Outcome.Kind != "continue" {
		t.Fatalf("expected preview stage to continue into post-preview contour, got %#v", artifact.Stages[3])
	}
	if artifact.Outcome.ProviderError == nil {
		t.Fatalf("expected provider error outcome, got %#v", artifact.Outcome)
	}
	if artifact.Outcome.ProviderError.Stage != fixture.Expected.ProviderError.Stage {
		t.Fatalf("artifact stage = %q, want %q", artifact.Outcome.ProviderError.Stage, fixture.Expected.ProviderError.Stage)
	}
	if artifact.Outcome.ProviderError.Code != fixture.Expected.ProviderError.Code {
		t.Fatalf("artifact code = %q, want %q", artifact.Outcome.ProviderError.Code, fixture.Expected.ProviderError.Code)
	}
}

func TestResolveReturnsTurnCredentialsFromObservedPostPreviewContour(t *testing.T) {
	previewFixture := loadFixture(t, "vk_call_debug_live_browser_preview_only_v1.json")
	successFixture := loadFixture(t, "vk_call_debug_success_v1.json")
	doer := &fixtureDoer{t: t, stages: previewFixture.Stages[:2]}
	adapter := NewWithHTTPDoer(doer)

	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		return &provider.BrowserContinuation{
			StageResults: []provider.BrowserStageResult{
				browserObservedResultFromFixture(previewFixture.Stages[2]),
				browserObservedResultFromFixture(previewFixture.Stages[3]),
				browserObservedResultFromFixture(successFixture.Stages[2]),
				browserObservedResultFromFixture(successFixture.Stages[3]),
			},
		}, nil
	}))

	resolution, err := adapter.Resolve(ctx, "https://vk.com/call/join/test-token")
	if err != nil {
		t.Fatalf("Resolve() error = %v", err)
	}
	if resolution.Credentials.Username != successFixture.Expected.Resolution.Username {
		t.Fatalf("unexpected username %q", resolution.Credentials.Username)
	}
	if resolution.Credentials.Password != successFixture.Expected.Resolution.Password {
		t.Fatalf("unexpected password %q", resolution.Credentials.Password)
	}
	if resolution.Credentials.Address != successFixture.Expected.Resolution.Address {
		t.Fatalf("unexpected address %q", resolution.Credentials.Address)
	}
	if doer.calls != 2 {
		t.Fatalf("unexpected HTTP call count %d", doer.calls)
	}
	if resolution.Artifact == nil || len(resolution.Artifact.Stages) != 6 {
		t.Fatalf("unexpected artifact %#v", resolution.Artifact)
	}
	if resolution.Artifact.Stages[3].Name != stageGetCallPreview || resolution.Artifact.Stages[3].Outcome.Kind != "continue" {
		t.Fatalf("expected preview stage to continue into post-preview contour, got %#v", resolution.Artifact.Stages[3])
	}
	if resolution.Artifact.Outcome.Resolution == nil || resolution.Artifact.Outcome.Resolution.Address != successFixture.Expected.Resolution.Address {
		t.Fatalf("unexpected artifact resolution %#v", resolution.Artifact.Outcome)
	}
}

func TestResolveFailsWhenBrowserContinuationFails(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_browser_continuation_failed_v1.json")
	doer := &fixtureDoer{t: t, stages: fixture.Stages[:2]}
	adapter := NewWithHTTPDoer(doer)

	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		return nil, errors.New("controlled browser unavailable")
	}))

	_, err := adapter.Resolve(ctx, "https://vk.com/call/join/test-token")
	if err == nil {
		t.Fatal("Resolve() expected error")
	}

	var stageErr *stageError
	if !errors.As(err, &stageErr) {
		t.Fatalf("expected stageError, got %T", err)
	}
	if stageErr.code != fixture.Expected.ProviderError.Code {
		t.Fatalf("unexpected code %q", stageErr.code)
	}
}

func TestResolveFailsWhenBrowserOwnedStageStillReturnsCaptcha(t *testing.T) {
	fixture := loadFixture(t, "vk_call_debug_browser_continuation_failed_v1.json")
	doer := &fixtureDoer{t: t, stages: fixture.Stages[:2]}
	adapter := NewWithHTTPDoer(doer)

	ctx := provider.WithBrowserContinuationHandler(context.Background(), provider.BrowserContinuationHandlerFunc(func(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
		return &provider.BrowserContinuation{
			StageResults: []provider.BrowserStageResult{
				{
					Stage:      fixture.Stages[2].Name,
					Method:     fixture.Stages[2].Request.Method,
					URL:        "https://api.vk.com/method/calls.getAnonymousToken?v=5.275&client_id=6287487",
					FormKeys:   []string{"access_token", "captcha_attempt", "captcha_sid", "captcha_ts", "name", "success_token", "vk_join_link"},
					StatusCode: fixture.Stages[2].Response.StatusCode,
					Body:       fixture.Stages[2].Response.Body,
				},
			},
		}, nil
	}))

	_, err := adapter.Resolve(ctx, "https://vk.com/call/join/test-token")
	if err == nil {
		t.Fatal("Resolve() expected error")
	}

	var stageErr *stageError
	if !errors.As(err, &stageErr) {
		t.Fatalf("expected stageError, got %T", err)
	}
	if stageErr.code != fixture.Expected.ProviderError.Code {
		t.Fatalf("unexpected code %q", stageErr.code)
	}

	var carrier provider.ArtifactCarrier
	if !errors.As(err, &carrier) {
		t.Fatalf("expected artifact carrier, got %T", err)
	}
	artifact := carrier.Artifact()
	if artifact == nil || len(artifact.Stages) != len(fixture.Stages) {
		t.Fatalf("unexpected artifact stages %#v", artifact)
	}
	if artifact.Outcome.ProviderError == nil || artifact.Outcome.ProviderError.Code != fixture.Expected.ProviderError.Code {
		t.Fatalf("unexpected artifact outcome %#v", artifact.Outcome)
	}
}

func assertObservedStage(t *testing.T, observations []provider.BrowserStageObservation, stage string, urlPrefix string) {
	t.Helper()

	for _, observation := range observations {
		if observation.Stage != stage {
			continue
		}
		if observation.URLPrefix != urlPrefix {
			t.Fatalf("browser stage observation URL prefix for %s = %q, want %q", stage, observation.URLPrefix, urlPrefix)
		}
		return
	}

	t.Fatalf("missing browser stage observation for %s", stage)
}

func assertObservedStageExactFormValue(t *testing.T, observations []provider.BrowserStageObservation, stage string, key string, want string) {
	t.Helper()

	for _, observation := range observations {
		if observation.Stage != stage {
			continue
		}
		if got := observation.RequiredFormValues[key]; got != want {
			t.Fatalf("browser stage observation exact form value for %s.%s = %q, want %q", stage, key, got, want)
		}
		return
	}

	t.Fatalf("missing browser stage observation for %s", stage)
}

func assertObservedStageAlternativeFormValue(t *testing.T, observations []provider.BrowserStageObservation, stage string, key string, want string) {
	t.Helper()

	for _, observation := range observations {
		if observation.Stage != stage {
			continue
		}
		for _, value := range observation.RequiredFormValueAlternatives[key] {
			if value == want {
				return
			}
		}
		t.Fatalf("browser stage observation alternative form values for %s.%s = %#v, want to contain %q", stage, key, observation.RequiredFormValueAlternatives[key], want)
	}

	t.Fatalf("missing browser stage observation for %s", stage)
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

func browserObservedStageURL(stage fixtureStage) string {
	switch stage.Name {
	case stageBrowserLoginAnonymTokenMessages:
		return liveLoginAnonymTokenURL + "&app_id=6287487"
	case stageGetCallPreview:
		return getCallPreviewURL + "?v=5.275&client_id=6287487"
	case stageOKAnonymLogin, stageJoinConversationByURL:
		return okAPIURL
	default:
		return endpointURL(stage.EndpointID)
	}
}

func browserObservedResultFromFixture(stage fixtureStage) provider.BrowserStageResult {
	return provider.BrowserStageResult{
		Stage:      stage.Name,
		Method:     stage.Request.Method,
		URL:        browserObservedStageURL(stage),
		FormKeys:   append([]string(nil), stage.Request.FormKeys...),
		StatusCode: stage.Response.StatusCode,
		Body:       stage.Response.Body,
	}
}
