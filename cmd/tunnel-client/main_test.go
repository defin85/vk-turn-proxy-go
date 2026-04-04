package main

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net"
	"net/http"
	"strings"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestNewRegistryIncludesGenericTurn(t *testing.T) {
	registry := newRegistry()

	for _, name := range []string{"generic-turn", "vk"} {
		adapter, err := registry.Get(name)
		if err != nil {
			t.Fatalf("registry.Get(%q) error = %v", name, err)
		}
		if adapter.Name() != name {
			t.Fatalf("unexpected adapter name %q for %q", adapter.Name(), name)
		}
	}
}

func TestRunClientRejectsInvalidConfig(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "",
		"-peer", "127.0.0.1:56000",
	}, newRegistry())
	if code != 2 {
		t.Fatalf("runClient() code = %d, stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stderr.String(), "invalid client config:") {
		t.Fatalf("stderr missing invalid config message: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=policy_validate") {
		t.Fatalf("stdout missing structured policy_validate event: %s", stdout.String())
	}
}

func TestRunClientReportsStageAwareFailure(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-bind-interface", "eth0",
	}, provider.NewRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stderr.String(), "stage=policy_validate") {
		t.Fatalf("stderr missing stage: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=policy_validate") {
		t.Fatalf("stdout missing structured policy_validate event: %s", stdout.String())
	}
}

func TestRunClientAllowsSupervisedPolicyToReachRuntime(t *testing.T) {
	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-connections", "2",
		"-mode", "tcp",
		"-dtls=false",
		"-bind-interface", "127.0.0.1",
	}, provider.NewRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s", code, stderr.String())
	}
	if !strings.Contains(stderr.String(), "stage=provider_resolve") {
		t.Fatalf("stderr missing provider_resolve stage: %s", stderr.String())
	}
}

func TestRunClientEmitsStructuredMetricsListenFailure(t *testing.T) {
	metricsListener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatalf("listen metrics addr: %v", err)
	}
	defer metricsListener.Close()

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), bytes.NewBuffer(nil), &stdout, &stderr, []string{
		"-provider", "generic-turn",
		"-link", "generic-turn://user:pass@turn.example.test:3478",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-metrics-listen", metricsListener.Addr().String(),
	}, newRegistry())
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s stdout=%s", code, stderr.String(), stdout.String())
	}
	if !strings.Contains(stderr.String(), "client metrics failed:") {
		t.Fatalf("stderr missing metrics failure: %s", stderr.String())
	}
	if !strings.Contains(stdout.String(), "event=runtime_failure") || !strings.Contains(stdout.String(), "stage=metrics_listen") {
		t.Fatalf("stdout missing structured metrics_listen event: %s", stdout.String())
	}
}

type interactiveAdapter struct {
	name string
}

func (a interactiveAdapter) Name() string { return a.name }

func (a interactiveAdapter) Resolve(ctx context.Context, link string) (provider.Resolution, error) {
	handler := provider.BrowserContinuationHandlerFromContext(ctx)
	if handler == nil {
		return provider.Resolution{}, errors.New("browser continuation handler is required")
	}
	if _, err := handler.Continue(ctx, fakeClientChallenge{
		provider: "vk",
		stage:    "vk_calls_get_anonymous_token",
		kind:     "captcha",
		prompt:   "complete captcha",
		openURL:  "https://example.test/challenge",
	}); err != nil {
		return provider.Resolution{}, err
	}

	return provider.Resolution{}, errors.New("provider challenge completed")
}

type fakeClientChallenge struct {
	provider string
	stage    string
	kind     string
	prompt   string
	openURL  string
}

func (f fakeClientChallenge) ProviderName() string { return f.provider }
func (f fakeClientChallenge) StageName() string    { return f.stage }
func (f fakeClientChallenge) Kind() string         { return f.kind }
func (f fakeClientChallenge) Prompt() string       { return f.prompt }
func (f fakeClientChallenge) OpenURL() string      { return f.openURL }
func (f fakeClientChallenge) CookieURLs() []string { return []string{"https://api.vk.ru/"} }

type fakeInteractiveProviderHandler struct {
	continueFn func(context.Context, provider.InteractiveChallenge) (*provider.BrowserContinuation, error)
}

func (h fakeInteractiveProviderHandler) Handle(ctx context.Context, challenge provider.InteractiveChallenge) error {
	if h.continueFn == nil {
		return nil
	}
	_, err := h.continueFn(ctx, challenge)
	return err
}

func (h fakeInteractiveProviderHandler) Continue(ctx context.Context, challenge provider.InteractiveChallenge) (*provider.BrowserContinuation, error) {
	if h.continueFn == nil {
		return &provider.BrowserContinuation{}, nil
	}
	return h.continueFn(ctx, challenge)
}

func TestRunClientInteractiveProviderChallenge(t *testing.T) {
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

	var stdout bytes.Buffer
	var stderr bytes.Buffer
	code := runClient(context.Background(), strings.NewReader("continue\n"), &stdout, &stderr, []string{
		"-provider", "vk",
		"-link", "https://vk.com/call/join/test-token",
		"-listen", "127.0.0.1:9000",
		"-peer", "127.0.0.1:56000",
		"-interactive-provider",
	}, provider.NewRegistry(interactiveAdapter{name: "vk"}))
	if code != 1 {
		t.Fatalf("runClient() code = %d, stderr=%s stdout=%s", code, stderr.String(), stdout.String())
	}
	if !strings.Contains(stderr.String(), "stage=provider_resolve") {
		t.Fatalf("stderr missing provider_resolve stage: %s", stderr.String())
	}
	if !calledContinue {
		t.Fatal("expected browser continuation handler to be called")
	}
}
