package providerprompt

import (
	"context"
	"errors"
	"net/http"
	"os/exec"
	"path/filepath"
	"slices"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestChromiumLaunchArgsDefaultToInteractive(t *testing.T) {
	t.Setenv("CI", "")
	t.Setenv("GITHUB_ACTIONS", "")
	t.Setenv("ACT", "")
	t.Setenv(browserHeadlessEnv, "")
	previousEUID := currentEUID
	currentEUID = func() int { return 1000 }
	t.Cleanup(func() { currentEUID = previousEUID })

	args := chromiumLaunchArgs("/tmp/browser-profile", 9222)

	if !slices.Contains(args, "--new-window") {
		t.Fatalf("expected interactive launch args, got %#v", args)
	}
	if slices.Contains(args, "--headless=new") {
		t.Fatalf("did not expect headless launch args by default, got %#v", args)
	}
	if slices.Contains(args, "--no-sandbox") {
		t.Fatalf("did not expect no-sandbox for non-root interactive launch, got %#v", args)
	}
}

func TestChromiumLaunchArgsDisableSandboxForRootInteractiveLaunch(t *testing.T) {
	t.Setenv("CI", "")
	t.Setenv("GITHUB_ACTIONS", "")
	t.Setenv("ACT", "")
	t.Setenv(browserHeadlessEnv, "")
	previousEUID := currentEUID
	currentEUID = func() int { return 0 }
	t.Cleanup(func() { currentEUID = previousEUID })

	args := chromiumLaunchArgs("/tmp/browser-profile", 9222)

	if !slices.Contains(args, "--new-window") {
		t.Fatalf("expected interactive launch args, got %#v", args)
	}
	if !slices.Contains(args, "--no-sandbox") {
		t.Fatalf("expected no-sandbox for root interactive launch, got %#v", args)
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

func TestMatchObservationRejectsMissingRequiredFormKeys(t *testing.T) {
	observations := []provider.BrowserStageObservation{
		{
			Stage:            "ok_join_conversation_by_link",
			Method:           http.MethodPost,
			URLPrefix:        "https://calls.okcdn.ru/fb.do",
			RequiredFormKeys: []string{"anonymToken", "session_key"},
			RequiredFormValues: map[string]string{
				"method": "vchat.joinConversationByLink",
			},
		},
	}

	if _, ok := matchObservation(observations, http.MethodPost, "https://calls.okcdn.ru/fb.do", map[string]string{
		"method":      "vchat.joinConversationByLink",
		"anonymToken": "anon-token",
	}); ok {
		t.Fatal("expected observation mismatch when session_key is missing")
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

func TestNewBrowserOperationContextFollowsCallerCancellation(t *testing.T) {
	baseCtx, baseCancel := context.WithCancel(context.Background())
	defer baseCancel()
	callerCtx, callerCancel := context.WithCancel(context.Background())

	opCtx, cancel := newBrowserOperationContext(baseCtx, callerCtx, 0)
	defer cancel()

	callerCancel()

	select {
	case <-opCtx.Done():
	case <-time.After(time.Second):
		t.Fatal("operation context did not cancel after caller cancellation")
	}
	if !errors.Is(opCtx.Err(), context.Canceled) {
		t.Fatalf("operation context error = %v, want context.Canceled", opCtx.Err())
	}
}

func TestNewBrowserOperationContextFollowsTimeout(t *testing.T) {
	baseCtx, baseCancel := context.WithCancel(context.Background())
	defer baseCancel()

	opCtx, cancel := newBrowserOperationContext(baseCtx, context.Background(), 10*time.Millisecond)
	defer cancel()

	select {
	case <-opCtx.Done():
	case <-time.After(time.Second):
		t.Fatal("operation context did not time out")
	}
	if !errors.Is(opCtx.Err(), context.DeadlineExceeded) {
		t.Fatalf("operation context error = %v, want context.DeadlineExceeded", opCtx.Err())
	}
}

func TestResolveBrowserPathWithExplicitEnvWins(t *testing.T) {
	path, err := resolveBrowserPathWith("windows", func(key string) string {
		if key == "VK_PROVIDER_BROWSER" {
			return `C:\Tools\Chrome\chrome.exe`
		}
		return ""
	}, func(string) (string, error) {
		t.Fatal("lookPath should not be called when VK_PROVIDER_BROWSER is set")
		return "", nil
	}, func(string) bool {
		t.Fatal("pathExists should not be called when VK_PROVIDER_BROWSER is set")
		return false
	})
	if err != nil {
		t.Fatalf("resolveBrowserPathWith() error = %v", err)
	}
	if path != `C:\Tools\Chrome\chrome.exe` {
		t.Fatalf("resolveBrowserPathWith() path = %q", path)
	}
}

func TestResolveBrowserPathWithWindowsUsesPATHCandidates(t *testing.T) {
	var lookedUp []string
	path, err := resolveBrowserPathWith("windows", func(string) string {
		return ""
	}, func(name string) (string, error) {
		lookedUp = append(lookedUp, name)
		if name == "msedge.exe" {
			return `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`, nil
		}
		return "", exec.ErrNotFound
	}, func(string) bool {
		t.Fatal("pathExists should not be called when browser is found in PATH")
		return false
	})
	if err != nil {
		t.Fatalf("resolveBrowserPathWith() error = %v", err)
	}
	if path != `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe` {
		t.Fatalf("resolveBrowserPathWith() path = %q", path)
	}
	if !slices.Contains(lookedUp, "chrome.exe") || !slices.Contains(lookedUp, "msedge.exe") {
		t.Fatalf("resolveBrowserPathWith() looked up %#v, want chrome.exe and msedge.exe", lookedUp)
	}
}

func TestResolveBrowserPathWithWindowsFallsBackToInstallPaths(t *testing.T) {
	localAppData := `C:/Users/Egor/AppData/Local`
	expected := filepath.Clean(filepath.Join(localAppData, "Google", "Chrome", "Application", "chrome.exe"))
	path, err := resolveBrowserPathWith("windows", func(key string) string {
		switch key {
		case "LOCALAPPDATA":
			return localAppData
		default:
			return ""
		}
	}, func(string) (string, error) {
		return "", exec.ErrNotFound
	}, func(candidate string) bool {
		return filepath.Clean(candidate) == expected
	})
	if err != nil {
		t.Fatalf("resolveBrowserPathWith() error = %v", err)
	}
	if filepath.Clean(path) != expected {
		t.Fatalf("resolveBrowserPathWith() path = %q, want %q", path, expected)
	}
}
