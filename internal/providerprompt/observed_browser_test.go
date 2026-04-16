package providerprompt

import (
	"net/http"
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestBuildObservedStageResultsMatchesAndPreservesOrder(t *testing.T) {
	observations := []provider.BrowserStageObservation{
		{
			Stage:     "preview",
			Method:    http.MethodPost,
			URLPrefix: "https://api.vk.com/method/calls.getCallPreview",
			RequiredFormKeys: []string{
				"access_token",
				"anonymous_token",
			},
		},
		{
			Stage:     "join",
			Method:    http.MethodPost,
			URLPrefix: "https://calls.okcdn.ru/fb.do",
			RequiredFormValues: map[string]string{
				"method": "vchat.joinConversationByLink",
			},
		},
	}

	results := BuildObservedStageResults(
		observations,
		[]ObservedBrowserRequest{
			{
				Method: http.MethodGet,
				URL:    "https://example.test/ignored",
			},
			{
				Method: http.MethodPost,
				URL:    "https://api.vk.com/method/calls.getCallPreview?v=5.275",
				FormValues: map[string]string{
					"access_token":    "browser-token",
					"anonymous_token": "anon-token",
				},
				StatusCode: http.StatusOK,
				Body: map[string]any{
					"response": map[string]any{"call": "preview"},
				},
			},
			{
				Method: http.MethodPost,
				URL:    "https://calls.okcdn.ru/fb.do",
				FormValues: map[string]string{
					"method":   "vchat.joinConversationByLink",
					"joinLink": "https://vk.com/call/join/test-token",
				},
				StatusCode: http.StatusOK,
				Body: map[string]any{
					"username": "turn-user",
				},
			},
		},
	)

	if len(results) != 2 {
		t.Fatalf("BuildObservedStageResults() len = %d, want 2", len(results))
	}
	if results[0].Stage != "preview" {
		t.Fatalf("results[0].stage = %q, want preview", results[0].Stage)
	}
	if results[1].Stage != "join" {
		t.Fatalf("results[1].stage = %q, want join", results[1].Stage)
	}
}
