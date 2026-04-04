package providerprompt

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestChromiumSessionCollectsCookies(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping controlled browser integration in short mode")
	}
	if _, err := resolveBrowserPath(); err != nil {
		t.Skipf("browser not available: %v", err)
	}

	server := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		http.SetCookie(writer, &http.Cookie{
			Name:     "vkprobe",
			Value:    "cookie-value",
			Path:     "/",
			HttpOnly: true,
		})
		writer.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = writer.Write([]byte("<html><body>challenge</body></html>"))
	}))
	defer server.Close()

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	session, err := newChromiumSession(ctx)
	if err != nil {
		t.Fatalf("newChromiumSession() error = %v", err)
	}
	defer func() {
		_ = session.Close()
	}()

	if err := session.Open(ctx, server.URL); err != nil {
		t.Fatalf("Open() error = %v", err)
	}

	cookies, err := session.Cookies(ctx, []string{server.URL})
	if err != nil {
		t.Fatalf("Cookies() error = %v", err)
	}

	for _, cookie := range cookies {
		if cookie != nil && cookie.Name == "vkprobe" && cookie.Value == "cookie-value" {
			return
		}
	}

	t.Fatalf("expected browser cookie for %s, got %#v", server.URL, cookies)
}

func TestChromiumSessionExecutesBrowserOwnedStageRequest(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping controlled browser integration in short mode")
	}
	if _, err := resolveBrowserPath(); err != nil {
		t.Skipf("browser not available: %v", err)
	}

	var challengeOrigin string
	stageServer := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if challengeOrigin != "" {
			writer.Header().Set("Access-Control-Allow-Origin", challengeOrigin)
			writer.Header().Set("Access-Control-Allow-Credentials", "true")
		}
		if request.Method != http.MethodPost {
			t.Fatalf("unexpected method %s", request.Method)
		}
		if err := request.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		if request.PostForm.Get("access_token") != "token-value" {
			t.Fatalf("unexpected access_token %q", request.PostForm.Get("access_token"))
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"response":{"token":"browser-owned-token"}}`))
	}))
	defer stageServer.Close()

	challengeServer := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = writer.Write([]byte("<html><body>challenge</body></html>"))
	}))
	defer challengeServer.Close()
	challengeOrigin = challengeServer.URL

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	session, err := newChromiumSession(ctx)
	if err != nil {
		t.Fatalf("newChromiumSession() error = %v", err)
	}
	defer func() {
		_ = session.Close()
	}()

	if err := session.Open(ctx, challengeServer.URL); err != nil {
		t.Fatalf("Open() error = %v", err)
	}

	results, err := session.ExecuteStageRequests(ctx, []provider.BrowserStageRequest{
		{
			Stage:  "vk_calls_get_anonymous_token",
			Method: http.MethodPost,
			URL:    stageServer.URL,
			Form: map[string]string{
				"vk_join_link": "https://vk.com/call/join/test-token",
				"name":         "123",
				"access_token": "token-value",
			},
		},
	})
	if err != nil {
		t.Fatalf("ExecuteStageRequests() error = %v", err)
	}
	if len(results) != 1 {
		t.Fatalf("unexpected stage results %#v", results)
	}
	if results[0].StatusCode != http.StatusOK {
		t.Fatalf("unexpected status %d", results[0].StatusCode)
	}
	response, ok := results[0].Body["response"].(map[string]any)
	if !ok || response["token"] != "browser-owned-token" {
		t.Fatalf("unexpected stage result body %#v", results[0].Body)
	}
}

func TestChromiumSessionObservesBrowserOwnedStageResult(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping controlled browser integration in short mode")
	}
	if _, err := resolveBrowserPath(); err != nil {
		t.Skipf("browser not available: %v", err)
	}

	var challengeOrigin string
	stageServer := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if challengeOrigin != "" {
			writer.Header().Set("Access-Control-Allow-Origin", challengeOrigin)
			writer.Header().Set("Access-Control-Allow-Credentials", "true")
		}
		if request.Method != http.MethodPost {
			t.Fatalf("unexpected method %s", request.Method)
		}
		if err := request.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"response":{"token":"browser-observed-token"}}`))
	}))
	defer stageServer.Close()

	challengeServer := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = writer.Write([]byte(fmt.Sprintf(`<html><body><script>
setTimeout(() => {
  fetch(%q, {
    method: "POST",
    credentials: "include",
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: new URLSearchParams({
      "vk_join_link": "https://vk.com/call/join/test-token",
      "name": "123",
      "captcha_sid": "test-sid",
      "captcha_attempt": "1",
      "captcha_ts": "1775268146.9",
      "success_token": "test-success-token",
      "access_token": "token-value"
    })
  });
}, 200);
</script>challenge</body></html>`, stageServer.URL)))
	}))
	defer challengeServer.Close()
	challengeOrigin = challengeServer.URL

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	session, err := newChromiumSession(ctx)
	if err != nil {
		t.Fatalf("newChromiumSession() error = %v", err)
	}
	defer func() {
		_ = session.Close()
	}()

	if err := session.Open(ctx, challengeServer.URL); err != nil {
		t.Fatalf("Open() error = %v", err)
	}

	confirmed := make(chan struct{})
	resultsCh := make(chan []provider.BrowserStageResult, 1)
	errCh := make(chan error, 1)
	go func() {
		results, err := session.ObserveStageResults(ctx, []provider.BrowserStageObservation{
			{
				Stage:     "vk_calls_get_anonymous_token",
				Method:    http.MethodPost,
				URLPrefix: stageServer.URL,
			},
		}, confirmed, nil)
		if err != nil {
			errCh <- err
			return
		}
		resultsCh <- results
	}()

	time.Sleep(500 * time.Millisecond)
	close(confirmed)

	select {
	case err := <-errCh:
		t.Fatalf("ObserveStageResults() error = %v", err)
	case results := <-resultsCh:
		if len(results) != 1 {
			t.Fatalf("unexpected stage results %#v", results)
		}
		if results[0].StatusCode != http.StatusOK {
			t.Fatalf("unexpected status %d", results[0].StatusCode)
		}
		if len(results[0].FormKeys) != 7 {
			t.Fatalf("unexpected observed form keys %#v", results[0].FormKeys)
		}
		response, ok := results[0].Body["response"].(map[string]any)
		if !ok || response["token"] != "browser-observed-token" {
			t.Fatalf("unexpected stage result body %#v", results[0].Body)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("ObserveStageResults() timed out")
	}
}

func TestChromiumSessionObservesStageResultDuringInitialPageLoad(t *testing.T) {
	if testing.Short() {
		t.Skip("skipping controlled browser integration in short mode")
	}
	if _, err := resolveBrowserPath(); err != nil {
		t.Skipf("browser not available: %v", err)
	}

	var challengeOrigin string
	stageServer := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if challengeOrigin != "" {
			writer.Header().Set("Access-Control-Allow-Origin", challengeOrigin)
			writer.Header().Set("Access-Control-Allow-Credentials", "true")
		}
		if request.Method != http.MethodPost {
			t.Fatalf("unexpected method %s", request.Method)
		}
		if err := request.ParseForm(); err != nil {
			t.Fatalf("parse form: %v", err)
		}
		writer.Header().Set("Content-Type", "application/json")
		_, _ = writer.Write([]byte(`{"response":{"token":"browser-observed-on-load"}}`))
	}))
	defer stageServer.Close()

	challengeServer := httptest.NewServer(http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		writer.Header().Set("Content-Type", "text/html; charset=utf-8")
		_, _ = writer.Write([]byte(fmt.Sprintf(`<html><body><script>
fetch(%q, {
  method: "POST",
  credentials: "include",
  headers: {"Content-Type": "application/x-www-form-urlencoded"},
  body: new URLSearchParams({
    "vk_join_link": "https://vk.com/call/join/test-token",
    "name": "123",
    "captcha_sid": "test-sid",
    "captcha_attempt": "1",
    "captcha_ts": "1775268146.9",
    "success_token": "test-success-token",
    "access_token": "token-value"
  })
});
</script>challenge</body></html>`, stageServer.URL)))
	}))
	defer challengeServer.Close()
	challengeOrigin = challengeServer.URL

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	session, err := newChromiumSession(ctx)
	if err != nil {
		t.Fatalf("newChromiumSession() error = %v", err)
	}
	defer func() {
		_ = session.Close()
	}()

	confirmed := make(chan struct{})
	ready := make(chan struct{})
	resultsCh := make(chan []provider.BrowserStageResult, 1)
	errCh := make(chan error, 1)
	go func() {
		results, err := session.ObserveStageResults(ctx, []provider.BrowserStageObservation{
			{
				Stage:     "vk_calls_get_anonymous_token",
				Method:    http.MethodPost,
				URLPrefix: stageServer.URL,
			},
		}, confirmed, ready)
		if err != nil {
			errCh <- err
			return
		}
		resultsCh <- results
	}()

	select {
	case <-ready:
	case err := <-errCh:
		t.Fatalf("ObserveStageResults() early error = %v", err)
	case <-time.After(5 * time.Second):
		t.Fatal("ObserveStageResults() did not arm before open")
	}

	if err := session.Open(ctx, challengeServer.URL); err != nil {
		t.Fatalf("Open() error = %v", err)
	}

	time.Sleep(500 * time.Millisecond)
	close(confirmed)

	select {
	case err := <-errCh:
		t.Fatalf("ObserveStageResults() error = %v", err)
	case results := <-resultsCh:
		if len(results) != 1 {
			t.Fatalf("unexpected stage results %#v", results)
		}
		response, ok := results[0].Body["response"].(map[string]any)
		if !ok || response["token"] != "browser-observed-on-load" {
			t.Fatalf("unexpected stage result body %#v", results[0].Body)
		}
	case <-time.After(5 * time.Second):
		t.Fatal("ObserveStageResults() timed out")
	}
}
