package clientcontrol

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/providerprompt"
)

func browserContinuationFromChallengeAction(
	ctx context.Context,
	challenge provider.InteractiveChallenge,
	action challengeAction,
) (*provider.BrowserContinuation, error) {
	if action.browserContinuation == nil {
		return nil, errors.New("owned browser continuation payload is required")
	}

	result := &provider.BrowserContinuation{
		Cookies: toProviderCookies(action.browserContinuation.Cookies),
	}
	if stageChallenge, ok := challenge.(provider.BrowserOwnedStageChallenge); ok {
		stageResults, err := providerprompt.ExecuteStageRequestsWithCookies(
			ctx,
			stageChallenge.BrowserStageRequests(),
			result.Cookies,
		)
		if err != nil {
			return nil, err
		}
		result.StageResults = append(result.StageResults, stageResults...)
	}
	if len(result.Cookies) == 0 && len(result.StageResults) == 0 {
		return nil, errors.New("owned browser continuation did not provide cookies or stage results")
	}
	return result, nil
}

func toProviderCookies(cookies []BrowserCookie) []*http.Cookie {
	if len(cookies) == 0 {
		return nil
	}

	out := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		name := strings.TrimSpace(cookie.Name)
		if name == "" {
			continue
		}
		value := cookie.Value
		domain := strings.TrimSpace(cookie.Domain)
		path := strings.TrimSpace(cookie.Path)
		if path == "" {
			path = "/"
		}
		httpCookie := &http.Cookie{
			Name:     name,
			Value:    value,
			Domain:   domain,
			Path:     path,
			Secure:   cookie.Secure,
			HttpOnly: cookie.HTTPOnly,
		}
		if !cookie.Expires.IsZero() {
			httpCookie.Expires = cookie.Expires.UTC()
		}
		out = append(out, httpCookie)
	}
	if len(out) == 0 {
		return nil
	}
	return out
}
