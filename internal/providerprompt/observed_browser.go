package providerprompt

import (
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

type ObservedBrowserRequest struct {
	Method     string
	URL        string
	FormValues map[string]string
	StatusCode int
	Body       map[string]any
}

func BuildObservedStageResults(
	observations []provider.BrowserStageObservation,
	requests []ObservedBrowserRequest,
) []provider.BrowserStageResult {
	if len(observations) == 0 || len(requests) == 0 {
		return nil
	}

	results := make([]provider.BrowserStageResult, 0, len(requests))
	for _, request := range requests {
		method := strings.TrimSpace(request.Method)
		rawURL := strings.TrimSpace(request.URL)
		if method == "" || rawURL == "" || request.StatusCode == 0 || len(request.Body) == 0 {
			continue
		}
		observation, ok := matchObservation(
			observations,
			method,
			rawURL,
			request.FormValues,
		)
		if !ok {
			continue
		}
		results = append(results, provider.BrowserStageResult{
			Stage:      observation.Stage,
			Method:     method,
			URL:        rawURL,
			FormKeys:   sortedKeys(request.FormValues),
			StatusCode: request.StatusCode,
			Body:       request.Body,
		})
	}
	if len(results) == 0 {
		return nil
	}
	return results
}
