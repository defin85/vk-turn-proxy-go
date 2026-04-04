package providerprompt

import (
	"net/http"
	"slices"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestChromiumLaunchArgsDefaultToInteractive(t *testing.T) {
	t.Setenv("CI", "")
	t.Setenv("GITHUB_ACTIONS", "")
	t.Setenv("ACT", "")
	t.Setenv(browserHeadlessEnv, "")

	args := chromiumLaunchArgs("/tmp/browser-profile", 9222)

	if !slices.Contains(args, "--new-window") {
		t.Fatalf("expected interactive launch args, got %#v", args)
	}
	if slices.Contains(args, "--headless=new") {
		t.Fatalf("did not expect headless launch args by default, got %#v", args)
	}
}

func TestChromiumLaunchArgsUseHeadlessInCI(t *testing.T) {
	t.Setenv("GITHUB_ACTIONS", "")
	t.Setenv("ACT", "")
	t.Setenv(browserHeadlessEnv, "")
	t.Setenv("CI", "true")

	args := chromiumLaunchArgs("/tmp/browser-profile", 9222)
	for _, required := range []string{"--headless=new", "--disable-gpu", "--no-sandbox", "--disable-dev-shm-usage"} {
		if !slices.Contains(args, required) {
			t.Fatalf("expected %q in headless launch args %#v", required, args)
		}
	}
	if slices.Contains(args, "--new-window") {
		t.Fatalf("did not expect interactive launch args in CI, got %#v", args)
	}
}

func TestChromiumLaunchArgsRespectExplicitHeadlessOverride(t *testing.T) {
	t.Setenv("CI", "true")
	t.Setenv("GITHUB_ACTIONS", "")
	t.Setenv("ACT", "")
	t.Setenv(browserHeadlessEnv, "false")

	args := chromiumLaunchArgs("/tmp/browser-profile", 9222)
	if slices.Contains(args, "--headless=new") {
		t.Fatalf("did not expect headless launch args when override is false, got %#v", args)
	}
	if !slices.Contains(args, "--new-window") {
		t.Fatalf("expected interactive launch args when override is false, got %#v", args)
	}
}

func TestMatchObservationUsesRequiredFormValues(t *testing.T) {
	observations := []provider.BrowserStageObservation{
		{
			Stage:     "ok_anonym_login",
			Method:    http.MethodPost,
			URLPrefix: "https://calls.okcdn.ru/fb.do",
			RequiredFormValues: map[string]string{
				"method": "auth.anonymLogin",
			},
		},
		{
			Stage:     "ok_join_conversation_by_link",
			Method:    http.MethodPost,
			URLPrefix: "https://calls.okcdn.ru/fb.do",
			RequiredFormValues: map[string]string{
				"method": "vchat.joinConversationByLink",
			},
		},
	}

	observation, ok := matchObservation(observations, http.MethodPost, "https://calls.okcdn.ru/fb.do", map[string]string{
		"method": "vchat.joinConversationByLink",
	})
	if !ok {
		t.Fatal("expected observation match")
	}
	if observation.Stage != "ok_join_conversation_by_link" {
		t.Fatalf("matched stage = %q, want ok_join_conversation_by_link", observation.Stage)
	}
}

func TestMatchObservationRejectsMismatchedRequiredFormValues(t *testing.T) {
	observations := []provider.BrowserStageObservation{
		{
			Stage:     "ok_anonym_login",
			Method:    http.MethodPost,
			URLPrefix: "https://calls.okcdn.ru/fb.do",
			RequiredFormValues: map[string]string{
				"method": "auth.anonymLogin",
			},
		},
	}

	if _, ok := matchObservation(observations, http.MethodPost, "https://calls.okcdn.ru/fb.do", map[string]string{
		"method": "vchat.joinConversationByLink",
	}); ok {
		t.Fatal("expected observation mismatch")
	}
}

func TestMatchObservationUsesAlternativeFormValues(t *testing.T) {
	observations := []provider.BrowserStageObservation{
		{
			Stage:     "ok_join_conversation_by_link",
			Method:    http.MethodPost,
			URLPrefix: "https://calls.okcdn.ru/fb.do",
			RequiredFormValues: map[string]string{
				"method": "vchat.joinConversationByLink",
			},
			RequiredFormValueAlternatives: map[string][]string{
				"joinLink": {"test-token", "https://vk.com/call/join/test-token"},
			},
		},
	}

	observation, ok := matchObservation(observations, http.MethodPost, "https://calls.okcdn.ru/fb.do", map[string]string{
		"method":   "vchat.joinConversationByLink",
		"joinLink": "https://vk.com/call/join/test-token",
	})
	if !ok {
		t.Fatal("expected observation match")
	}
	if observation.Stage != "ok_join_conversation_by_link" {
		t.Fatalf("matched stage = %q, want ok_join_conversation_by_link", observation.Stage)
	}
}
