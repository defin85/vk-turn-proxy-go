package providerprompt

import (
	"context"
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

// ContinuationSession keeps a controlled browser alive between the moment a
// challenge is surfaced and the moment the operator confirms completion.
type ContinuationSession struct {
	session browserSession

	challenge  provider.InteractiveChallenge
	cookieURLs []string

	observedResultsCh chan []provider.BrowserStageResult
	observationErrCh  chan error
	observationReady  chan struct{}
	confirmed         chan struct{}

	cancelObservation context.CancelFunc
}

func StartContinuation(ctx context.Context, challenge provider.InteractiveChallenge, options Options) (*ContinuationSession, error) {
	if challenge == nil {
		return nil, errors.New("interactive provider challenge is required")
	}

	challengeURL := strings.TrimSpace(challenge.OpenURL())
	if challengeURL == "" {
		return nil, errors.New("interactive provider challenge URL is required")
	}

	newBrowserSession := options.NewBrowserSession
	if newBrowserSession == nil {
		newBrowserSession = newChromiumSession
	}

	session, err := newBrowserSession(ctx)
	if err != nil {
		return nil, fmt.Errorf("start provider browser session: %w", err)
	}

	continuation := &ContinuationSession{
		session:    session,
		challenge:  challenge,
		cookieURLs: []string{challengeURL},
	}
	if browserChallenge, ok := challenge.(provider.BrowserContinuationChallenge); ok {
		if urls := browserChallenge.CookieURLs(); len(urls) > 0 {
			continuation.cookieURLs = append([]string(nil), urls...)
		}
	}

	if observedChallenge, ok := challenge.(provider.BrowserObservedStageChallenge); ok {
		observationCtx, cancelObservation := context.WithCancel(ctx)
		continuation.cancelObservation = cancelObservation
		continuation.confirmed = make(chan struct{})
		continuation.observedResultsCh = make(chan []provider.BrowserStageResult, 1)
		continuation.observationErrCh = make(chan error, 1)
		continuation.observationReady = make(chan struct{})
		go func() {
			stageResults, err := session.ObserveStageResults(
				observationCtx,
				observedChallenge.BrowserStageObservations(),
				continuation.confirmed,
				continuation.observationReady,
			)
			if err != nil {
				continuation.observationErrCh <- err
				return
			}
			continuation.observedResultsCh <- stageResults
		}()
		select {
		case <-ctx.Done():
			_ = continuation.Close()
			return nil, fmt.Errorf("observe browser continuation stage: %w", ctx.Err())
		case err := <-continuation.observationErrCh:
			_ = continuation.Close()
			return nil, fmt.Errorf("observe browser continuation stage: %w", err)
		case <-continuation.observationReady:
		}
	}

	if err := session.Open(ctx, challengeURL); err != nil {
		_ = continuation.Close()
		return nil, fmt.Errorf("open controlled browser challenge: %w", err)
	}

	return continuation, nil
}

func (c *ContinuationSession) Complete(ctx context.Context) (*provider.BrowserContinuation, error) {
	if c == nil {
		return nil, errors.New("provider continuation session is required")
	}
	if c.session == nil {
		return nil, errors.New("provider continuation browser session is required")
	}

	result := &provider.BrowserContinuation{}
	if c.confirmed != nil {
		select {
		case <-c.confirmed:
		default:
			close(c.confirmed)
		}
	}

	if c.observedResultsCh != nil {
		select {
		case <-ctx.Done():
			return nil, fmt.Errorf("observe browser continuation stage: %w", ctx.Err())
		case err := <-c.observationErrCh:
			return nil, fmt.Errorf("observe browser continuation stage: %w", err)
		case stageResults := <-c.observedResultsCh:
			result.StageResults = append(result.StageResults, stageResults...)
			return result, nil
		}
	}

	if stageChallenge, ok := c.challenge.(provider.BrowserOwnedStageChallenge); ok {
		stageResults, err := c.session.ExecuteStageRequests(ctx, stageChallenge.BrowserStageRequests())
		if err != nil {
			return nil, fmt.Errorf("execute browser continuation stage: %w", err)
		}
		result.StageResults = append(result.StageResults, stageResults...)
		return result, nil
	}

	cookies, err := c.session.Cookies(ctx, c.cookieURLs)
	if err != nil {
		return nil, fmt.Errorf("collect browser continuation cookies: %w", err)
	}
	result.Cookies = append(result.Cookies, cookies...)

	return result, nil
}

func (c *ContinuationSession) Close() error {
	if c == nil {
		return nil
	}
	if c.cancelObservation != nil {
		c.cancelObservation()
	}
	if c.session != nil {
		return c.session.Close()
	}
	return nil
}

func ContinuationPrompt(challenge provider.InteractiveChallenge) string {
	if challenge == nil {
		return ""
	}
	return strings.TrimSpace(challenge.Prompt())
}

func ContinuationOpenURL(challenge provider.InteractiveChallenge) string {
	if challenge == nil {
		return ""
	}
	return strings.TrimSpace(challenge.OpenURL())
}

func ContinuationCookieURLs(challenge provider.InteractiveChallenge) []string {
	if challenge == nil {
		return nil
	}
	if browserChallenge, ok := challenge.(provider.BrowserContinuationChallenge); ok {
		urls := browserChallenge.CookieURLs()
		out := make([]string, 0, len(urls))
		for _, candidate := range urls {
			if trimmed := strings.TrimSpace(candidate); trimmed != "" {
				out = append(out, trimmed)
			}
		}
		return out
	}
	if openURL := strings.TrimSpace(challenge.OpenURL()); openURL != "" {
		return []string{openURL}
	}
	return nil
}

func ContinuationCookies(cookies []*http.Cookie) []*http.Cookie {
	out := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		if cookie == nil {
			continue
		}
		copyCookie := *cookie
		out = append(out, &copyCookie)
	}
	return out
}
