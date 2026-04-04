package provider

import (
	"context"
	"net/http"
)

type InteractiveChallenge interface {
	ProviderName() string
	StageName() string
	Kind() string
	Prompt() string
	OpenURL() string
}

type InteractionHandler interface {
	Handle(context.Context, InteractiveChallenge) error
}

type InteractionHandlerFunc func(context.Context, InteractiveChallenge) error

func (f InteractionHandlerFunc) Handle(ctx context.Context, challenge InteractiveChallenge) error {
	if f == nil {
		return nil
	}

	return f(ctx, challenge)
}

type interactionHandlerContextKey struct{}

func WithInteractionHandler(ctx context.Context, handler InteractionHandler) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	if handler == nil {
		return ctx
	}

	return context.WithValue(ctx, interactionHandlerContextKey{}, handler)
}

func InteractionHandlerFromContext(ctx context.Context) InteractionHandler {
	if ctx == nil {
		return nil
	}

	handler, _ := ctx.Value(interactionHandlerContextKey{}).(InteractionHandler)
	return handler
}

type BrowserContinuation struct {
	Cookies      []*http.Cookie
	StageResults []BrowserStageResult
}

type BrowserStageObservation struct {
	Stage                         string
	Method                        string
	URLPrefix                     string
	RequiredFormValues            map[string]string
	RequiredFormValueAlternatives map[string][]string
}

type BrowserStageRequest struct {
	Stage  string
	Method string
	URL    string
	Form   map[string]string
}

type BrowserStageResult struct {
	Stage      string
	Method     string
	URL        string
	FormKeys   []string
	StatusCode int
	Body       map[string]any
}

func (c *BrowserContinuation) StageResult(stage string) (*BrowserStageResult, bool) {
	if c == nil {
		return nil, false
	}

	for i := len(c.StageResults) - 1; i >= 0; i-- {
		if c.StageResults[i].Stage == stage {
			return &c.StageResults[i], true
		}
	}

	return nil, false
}

type BrowserContinuationHandler interface {
	Continue(context.Context, InteractiveChallenge) (*BrowserContinuation, error)
}

type BrowserContinuationHandlerFunc func(context.Context, InteractiveChallenge) (*BrowserContinuation, error)

func (f BrowserContinuationHandlerFunc) Continue(ctx context.Context, challenge InteractiveChallenge) (*BrowserContinuation, error) {
	if f == nil {
		return nil, nil
	}

	return f(ctx, challenge)
}

type browserContinuationHandlerContextKey struct{}

func WithBrowserContinuationHandler(ctx context.Context, handler BrowserContinuationHandler) context.Context {
	if ctx == nil {
		ctx = context.Background()
	}
	if handler == nil {
		return ctx
	}

	return context.WithValue(ctx, browserContinuationHandlerContextKey{}, handler)
}

func BrowserContinuationHandlerFromContext(ctx context.Context) BrowserContinuationHandler {
	if ctx == nil {
		return nil
	}

	handler, _ := ctx.Value(browserContinuationHandlerContextKey{}).(BrowserContinuationHandler)
	return handler
}

type BrowserContinuationChallenge interface {
	InteractiveChallenge
	CookieURLs() []string
}

type BrowserOwnedStageChallenge interface {
	BrowserContinuationChallenge
	BrowserStageRequests() []BrowserStageRequest
}

type BrowserObservedStageChallenge interface {
	BrowserContinuationChallenge
	BrowserStageObservations() []BrowserStageObservation
}
