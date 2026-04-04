package vk

import "testing"

func TestSanitizeResponseBodyRedactsRequestParamsValues(t *testing.T) {
	payload := map[string]any{
		"error": map[string]any{
			"redirect_uri": "https://id.vk.ru/captcha?sid=raw",
			"request_params": []any{
				map[string]any{
					"key":   "vk_join_link",
					"value": "https://vk.com/call/join/live-secret-token",
				},
				map[string]any{
					"key":   "client_id",
					"value": "6287487",
				},
				map[string]any{
					"key":   "captcha_sid",
					"value": "raw-captcha-sid",
				},
				map[string]any{
					"key":   "captcha_key",
					"value": "raw-captcha-key",
				},
				map[string]any{
					"key":   "success_token",
					"value": "raw-success-token",
				},
			},
		},
	}

	sanitized := sanitizeResponseBody(stageGetAnonymousToken, payload)

	errorObject, ok := sanitized["error"].(map[string]any)
	if !ok {
		t.Fatalf("expected error object, got %#v", sanitized["error"])
	}
	if got := errorObject["redirect_uri"]; got != placeholderCaptchaURL {
		t.Fatalf("redirect_uri = %#v, want %q", got, placeholderCaptchaURL)
	}

	requestParams, ok := errorObject["request_params"].([]any)
	if !ok || len(requestParams) != 5 {
		t.Fatalf("unexpected request_params %#v", errorObject["request_params"])
	}

	first, ok := requestParams[0].(map[string]any)
	if !ok {
		t.Fatalf("unexpected first request param %#v", requestParams[0])
	}
	if got := first["value"]; got != placeholderInviteURL {
		t.Fatalf("vk_join_link value = %#v, want %q", got, placeholderInviteURL)
	}

	second, ok := requestParams[1].(map[string]any)
	if !ok {
		t.Fatalf("unexpected second request param %#v", requestParams[1])
	}
	if got := second["value"]; got != "6287487" {
		t.Fatalf("client_id value = %#v, want unchanged", got)
	}

	third, ok := requestParams[2].(map[string]any)
	if !ok {
		t.Fatalf("unexpected third request param %#v", requestParams[2])
	}
	if got := third["value"]; got != placeholderCaptchaSID {
		t.Fatalf("captcha_sid value = %#v, want %q", got, placeholderCaptchaSID)
	}

	fourth, ok := requestParams[3].(map[string]any)
	if !ok {
		t.Fatalf("unexpected fourth request param %#v", requestParams[3])
	}
	if got := fourth["value"]; got != placeholderCaptchaKey {
		t.Fatalf("captcha_key value = %#v, want %q", got, placeholderCaptchaKey)
	}

	fifth, ok := requestParams[4].(map[string]any)
	if !ok {
		t.Fatalf("unexpected fifth request param %#v", requestParams[4])
	}
	if got := fifth["value"]; got != placeholderSuccessToken {
		t.Fatalf("success_token value = %#v, want %q", got, placeholderSuccessToken)
	}
}
