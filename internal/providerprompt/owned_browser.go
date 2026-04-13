package providerprompt

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func ExecuteStageRequestsWithCookies(
	ctx context.Context,
	requests []provider.BrowserStageRequest,
	cookies []*http.Cookie,
) ([]provider.BrowserStageResult, error) {
	if len(requests) == 0 {
		return nil, nil
	}

	client := &http.Client{}
	results := make([]provider.BrowserStageResult, 0, len(requests))
	for _, request := range requests {
		result, err := executeStageRequestWithCookies(ctx, client, request, cookies)
		if err != nil {
			return nil, err
		}
		results = append(results, result)
	}
	return results, nil
}

func executeStageRequestWithCookies(
	ctx context.Context,
	client *http.Client,
	request provider.BrowserStageRequest,
	cookies []*http.Cookie,
) (provider.BrowserStageResult, error) {
	method := strings.ToUpper(strings.TrimSpace(request.Method))
	if method == "" {
		return provider.BrowserStageResult{}, errors.New("browser stage request method is required")
	}
	if method != http.MethodPost {
		return provider.BrowserStageResult{}, fmt.Errorf("unsupported browser stage request method %q", request.Method)
	}
	rawURL := strings.TrimSpace(request.URL)
	if rawURL == "" {
		return provider.BrowserStageResult{}, errors.New("browser stage request URL is required")
	}
	parsedURL, err := url.Parse(rawURL)
	if err != nil {
		return provider.BrowserStageResult{}, fmt.Errorf("parse browser stage request URL: %w", err)
	}

	form := url.Values{}
	for key, value := range request.Form {
		form.Set(key, value)
	}
	httpRequest, err := http.NewRequestWithContext(
		ctx,
		http.MethodPost,
		rawURL,
		bytes.NewBufferString(form.Encode()),
	)
	if err != nil {
		return provider.BrowserStageResult{}, fmt.Errorf("build browser stage request: %w", err)
	}
	httpRequest.Header.Set("Content-Type", "application/x-www-form-urlencoded")
	for _, cookie := range cookiesForURL(parsedURL, cookies) {
		httpRequest.AddCookie(cookie)
	}

	response, err := client.Do(httpRequest)
	if err != nil {
		return provider.BrowserStageResult{}, fmt.Errorf("execute browser stage request: %w", err)
	}
	defer response.Body.Close()

	body, err := decodeJSONBody(response.Body)
	if err != nil {
		return provider.BrowserStageResult{}, fmt.Errorf("decode browser stage response: %w", err)
	}

	return provider.BrowserStageResult{
		Stage:      request.Stage,
		Method:     http.MethodPost,
		URL:        rawURL,
		FormKeys:   sortedKeys(request.Form),
		StatusCode: response.StatusCode,
		Body:       body,
	}, nil
}

func decodeJSONBody(body io.Reader) (map[string]any, error) {
	if body == nil {
		return nil, errors.New("browser stage response body is required")
	}
	var payload map[string]any
	if err := json.NewDecoder(body).Decode(&payload); err != nil {
		return nil, err
	}
	if payload == nil {
		return nil, errors.New("browser stage response body is required")
	}
	return payload, nil
}

func cookiesForURL(target *url.URL, cookies []*http.Cookie) []*http.Cookie {
	if target == nil || len(cookies) == 0 {
		return nil
	}

	out := make([]*http.Cookie, 0, len(cookies))
	host := strings.ToLower(target.Hostname())
	path := target.EscapedPath()
	if path == "" {
		path = "/"
	}
	isHTTPS := strings.EqualFold(target.Scheme, "https")
	for _, cookie := range cookies {
		if cookie == nil {
			continue
		}
		if cookie.Secure && !isHTTPS {
			continue
		}
		if !cookieDomainMatches(host, cookie.Domain) {
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
		out = append(out, &copyCookie)
	}
	return out
}

func cookieDomainMatches(host string, domain string) bool {
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
