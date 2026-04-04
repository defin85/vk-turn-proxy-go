package providerprompt

import (
	"bytes"
	"context"
	"errors"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"
)

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
func (f fakeChallenge) CookieURLs() []string {
	return []string{"https://api.vk.ru/", "https://vk.com/"}
}

type fakeBrowserSession struct {
	openURL  string
	cookies  []*http.Cookie
	errOpen  error
	errFetch error
}

func (s *fakeBrowserSession) Open(ctx context.Context, challengeURL string) error {
	s.openURL = challengeURL
	return s.errOpen
}

func (s *fakeBrowserSession) Cookies(ctx context.Context, urls []string) ([]*http.Cookie, error) {
	if s.errFetch != nil {
		return nil, s.errFetch
	}
	return append([]*http.Cookie(nil), s.cookies...), nil
}

func (s *fakeBrowserSession) Close() error { return nil }

func TestHandlerOpensBrowserAndAcceptsContinue(t *testing.T) {
	var stderr bytes.Buffer
	var opened string
	handler := NewHandler(strings.NewReader("continue\n"), &stderr, Options{
		OpenURL: func(ctx context.Context, challengeURL string) error {
			opened = challengeURL
			return nil
		},
	})

	err := handler.Handle(context.Background(), fakeChallenge{
		provider: "vk",
		stage:    "vk_calls_get_anonymous_token",
		kind:     "captcha",
		prompt:   "complete captcha",
		openURL:  "https://example.test/challenge",
	})
	if err != nil {
		t.Fatalf("Handle() error = %v", err)
	}
	if opened != "https://example.test/challenge" {
		t.Fatalf("opened URL = %q", opened)
	}
	if !strings.Contains(stderr.String(), "browser opened for provider challenge") {
		t.Fatalf("stderr missing browser hint: %s", stderr.String())
	}
}

func TestHandlerRejectsUnexpectedConfirmation(t *testing.T) {
	var stderr bytes.Buffer
	handler := NewHandler(strings.NewReader("nope\n"), &stderr, Options{
		OpenURL: func(ctx context.Context, challengeURL string) error {
			return errors.New("not used")
		},
	})

	err := handler.Handle(context.Background(), fakeChallenge{
		provider: "vk",
		stage:    "vk_calls_get_anonymous_token",
		kind:     "captcha",
		prompt:   "complete captcha",
	})
	if err == nil {
		t.Fatal("Handle() expected error")
	}
	if !strings.Contains(err.Error(), "not confirmed") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestHandlerReturnsContextCancellation(t *testing.T) {
	var stderr bytes.Buffer
	reader, writer := io.Pipe()
	handler := NewHandler(reader, &stderr, Options{})

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Millisecond)
	defer cancel()

	err := handler.Handle(ctx, fakeChallenge{
		provider: "vk",
		stage:    "vk_calls_get_anonymous_token",
		kind:     "captcha",
		prompt:   "complete captcha",
	})
	_ = writer.Close()
	if err == nil {
		t.Fatal("Handle() expected error")
	}
	if !strings.Contains(err.Error(), "aborted") {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestHandlerContinueReturnsBrowserCookies(t *testing.T) {
	var stderr bytes.Buffer
	session := &fakeBrowserSession{
		cookies: []*http.Cookie{
			{Name: "remixsid", Value: "secret", Domain: ".vk.ru", Path: "/"},
		},
	}
	handler := NewHandler(strings.NewReader("continue\n"), &stderr, Options{
		NewBrowserSession: func(ctx context.Context) (browserSession, error) {
			return session, nil
		},
	})

	result, err := handler.Continue(context.Background(), fakeChallenge{
		provider: "vk",
		stage:    "vk_calls_get_anonymous_token",
		kind:     "captcha",
		prompt:   "complete captcha",
		openURL:  "https://example.test/challenge",
	})
	if err != nil {
		t.Fatalf("Continue() error = %v", err)
	}
	if session.openURL != "https://example.test/challenge" {
		t.Fatalf("session open URL = %q", session.openURL)
	}
	if result == nil || len(result.Cookies) != 1 {
		t.Fatalf("unexpected browser continuation %#v", result)
	}
	if !strings.Contains(stderr.String(), "controlled browser opened") {
		t.Fatalf("stderr missing controlled browser hint: %s", stderr.String())
	}
}

func TestHandlerContinueSurfacesCookieCollectionFailure(t *testing.T) {
	var stderr bytes.Buffer
	handler := NewHandler(strings.NewReader("continue\n"), &stderr, Options{
		NewBrowserSession: func(ctx context.Context) (browserSession, error) {
			return &fakeBrowserSession{errFetch: errors.New("cookies failed")}, nil
		},
	})

	_, err := handler.Continue(context.Background(), fakeChallenge{
		provider: "vk",
		stage:    "vk_calls_get_anonymous_token",
		kind:     "captcha",
		prompt:   "complete captcha",
		openURL:  "https://example.test/challenge",
	})
	if err == nil {
		t.Fatal("Continue() expected error")
	}
	if !strings.Contains(err.Error(), "collect browser continuation cookies") {
		t.Fatalf("unexpected error: %v", err)
	}
}
