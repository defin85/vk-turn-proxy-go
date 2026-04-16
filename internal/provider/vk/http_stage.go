package vk

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func newDefaultHTTPClient() *http.Client {
	transport := http.DefaultTransport.(*http.Transport).Clone()

	return &http.Client{
		Timeout:   20 * time.Second,
		Transport: transport,
	}
}

func (r *resolver) performStage(ctx context.Context, descriptor stageDescriptor, form url.Values) (map[string]any, provider.ProbeArtifactStage, error) {
	return r.performStageWithCookies(ctx, descriptor, form, nil)
}

func (r *resolver) performStageWithCookies(
	ctx context.Context,
	descriptor stageDescriptor,
	form url.Values,
	cookies []*http.Cookie,
) (map[string]any, provider.ProbeArtifactStage, error) {
	stage := provider.ProbeArtifactStage{
		Name:       descriptor.name,
		EndpointID: descriptor.name,
		Request: provider.ProbeArtifactStageRequest{
			Method:         http.MethodPost,
			FormKeys:       descriptor.formKeys,
			RedactedFields: descriptor.redactedFields,
		},
	}

	request, err := http.NewRequestWithContext(ctx, http.MethodPost, descriptor.endpointURL, strings.NewReader(form.Encode()))
	if err != nil {
		stage.Response = provider.ProbeArtifactStageResponse{
			StatusCode: 0,
			Body: map[string]any{
				"error": "build_request_failed",
			},
		}
		return nil, withStageOutcome(stage, "provider_error", nil, "build_request"), &stageError{stage: descriptor.name, code: "build_request", err: err}
	}
	request.Header.Set("User-Agent", userAgent)
	request.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	for _, cookie := range cookiesForStageURL(request.URL, cookies) {
		request.AddCookie(cookie)
	}

	response, err := r.doer.Do(request)
	if err != nil {
		stage.Response = provider.ProbeArtifactStageResponse{
			StatusCode: 0,
			Body: map[string]any{
				"error": "request_failed",
			},
		}
		return nil, withStageOutcome(stage, "provider_error", nil, "request_failed"), &stageError{stage: descriptor.name, code: "request_failed", err: err}
	}
	defer func() {
		_ = response.Body.Close()
	}()

	body, err := io.ReadAll(response.Body)
	if err != nil {
		stage.Response = provider.ProbeArtifactStageResponse{
			StatusCode: response.StatusCode,
			Body: map[string]any{
				"error": "read_body_failed",
			},
		}
		return nil, withStageOutcome(stage, "provider_error", nil, "read_body"), &stageError{stage: descriptor.name, code: "read_body", err: err}
	}
	if response.StatusCode != http.StatusOK {
		stage.Response = provider.ProbeArtifactStageResponse{
			StatusCode: response.StatusCode,
			Body: map[string]any{
				"error":         "unexpected_status",
				"body_redacted": true,
			},
		}
		return nil, withStageOutcome(stage, "provider_error", nil, "unexpected_status"), &stageError{
			stage: descriptor.name,
			code:  "unexpected_status",
			err:   fmt.Errorf("status=%s body=%s", response.Status, strings.TrimSpace(string(body))),
		}
	}

	var payload map[string]any
	if err := json.Unmarshal(body, &payload); err != nil {
		stage.Response = provider.ProbeArtifactStageResponse{
			StatusCode: response.StatusCode,
			Body: map[string]any{
				"error":         "decode_response_failed",
				"body_redacted": true,
			},
		}
		return nil, withStageOutcome(stage, "provider_error", nil, "decode_response"), &stageError{stage: descriptor.name, code: "decode_response", err: err}
	}

	stage.Response = provider.ProbeArtifactStageResponse{
		StatusCode: response.StatusCode,
		Body:       sanitizeResponseBody(descriptor.name, payload),
	}

	return payload, stage, nil
}

func cookiesForStageURL(target *url.URL, cookies []*http.Cookie) []*http.Cookie {
	if target == nil || len(cookies) == 0 {
		return nil
	}

	host := strings.ToLower(target.Hostname())
	path := target.EscapedPath()
	if path == "" {
		path = "/"
	}
	isHTTPS := strings.EqualFold(target.Scheme, "https")

	filtered := make([]*http.Cookie, 0, len(cookies))
	for _, cookie := range cookies {
		if cookie == nil {
			continue
		}
		if cookie.Secure && !isHTTPS {
			continue
		}
		if !stageCookieDomainMatches(host, cookie.Domain) {
			continue
		}
		cookiePath := cookie.Path
		if cookiePath == "" {
			cookiePath = "/"
		}
		if !strings.HasPrefix(path, cookiePath) {
			continue
		}
		copyCookie := *cookie
		filtered = append(filtered, &copyCookie)
	}

	return filtered
}

func stageCookieDomainMatches(host string, domain string) bool {
	trimmedHost := strings.TrimSpace(strings.ToLower(host))
	if trimmedHost == "" {
		return false
	}
	trimmedDomain := strings.TrimPrefix(strings.TrimSpace(strings.ToLower(domain)), ".")
	if trimmedDomain == "" {
		return true
	}
	return trimmedHost == trimmedDomain ||
		strings.HasSuffix(trimmedHost, "."+trimmedDomain)
}
