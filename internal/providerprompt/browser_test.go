package providerprompt

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
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
