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

func TestSanitizeResponseBodyRedactsLiveBrowserPreviewValues(t *testing.T) {
	payload := map[string]any{
		"response": map[string]any{
			"join_link":    "https://vk.com/call/join/live-secret-token",
			"access_token": "raw-browser-access-token",
			"token":        "raw-browser-preview-token",
			"call_id":      "3b08d584-e42a-4b69-86fe-fa72a3e71357",
			"title":        "Sensitive title",
			"ok_join_link": "raw-ok-join-link",
			"photo_400":    "https://cdn.example.test/photo-400.jpg",
			"photo_base":   "https://cdn.example.test/photo-base.jpg",
			"profiles": []any{
				map[string]any{
					"id":         372485183,
					"first_name": "Egor",
					"last_name":  "Mazalov",
					"photo_200":  "https://cdn.example.test/profile-200.jpg",
					"photo_base": "https://cdn.example.test/profile-base.jpg",
				},
			},
			"short_credentials": map[string]any{
				"id":                    "135-264-794",
				"link_with_password":    "https://vk.com/call/135-264-794?p=rjouzF",
				"link_without_password": "https://vk.com/call/135-264-794",
				"password":              "rjouzF",
			},
		},
	}

	sanitized := sanitizeResponseBody(stageGetCallPreview, payload)

	responseObject, ok := sanitized["response"].(map[string]any)
	if !ok {
		t.Fatalf("expected response object, got %#v", sanitized["response"])
	}
	if got := responseObject["join_link"]; got != placeholderInviteURL {
		t.Fatalf("join_link = %#v, want %q", got, placeholderInviteURL)
	}
	if got := responseObject["access_token"]; got != placeholderBrowserAccessToken {
		t.Fatalf("access_token = %#v, want %q", got, placeholderBrowserAccessToken)
	}
	if got := responseObject["token"]; got != placeholderAnonymousToken {
		t.Fatalf("token = %#v, want %q", got, placeholderAnonymousToken)
	}
	if got := responseObject["call_id"]; got != placeholderCallPreviewID {
		t.Fatalf("call_id = %#v, want %q", got, placeholderCallPreviewID)
	}
	if got := responseObject["title"]; got != placeholderCallPreviewTitle {
		t.Fatalf("title = %#v, want %q", got, placeholderCallPreviewTitle)
	}
	if got := responseObject["ok_join_link"]; got != placeholderOKJoinLink {
		t.Fatalf("ok_join_link = %#v, want %q", got, placeholderOKJoinLink)
	}
	if got := responseObject["photo_400"]; got != placeholderCallPreviewPhoto {
		t.Fatalf("photo_400 = %#v, want %q", got, placeholderCallPreviewPhoto)
	}
	if got := responseObject["photo_base"]; got != placeholderCallPreviewPhoto {
		t.Fatalf("photo_base = %#v, want %q", got, placeholderCallPreviewPhoto)
	}

	profiles, ok := responseObject["profiles"].([]any)
	if !ok || len(profiles) != 1 {
		t.Fatalf("profiles = %#v, want one profile", responseObject["profiles"])
	}
	profile, ok := profiles[0].(map[string]any)
	if !ok {
		t.Fatalf("profile = %#v, want object", profiles[0])
	}
	if got := profile["id"]; got != placeholderProfileID {
		t.Fatalf("profile.id = %#v, want %q", got, placeholderProfileID)
	}
	if got := profile["first_name"]; got != placeholderProfileFirstName {
		t.Fatalf("profile.first_name = %#v, want %q", got, placeholderProfileFirstName)
	}
	if got := profile["last_name"]; got != placeholderProfileLastName {
		t.Fatalf("profile.last_name = %#v, want %q", got, placeholderProfileLastName)
	}
	if got := profile["photo_200"]; got != placeholderProfilePhoto {
		t.Fatalf("profile.photo_200 = %#v, want %q", got, placeholderProfilePhoto)
	}
	if got := profile["photo_base"]; got != placeholderProfilePhoto {
		t.Fatalf("profile.photo_base = %#v, want %q", got, placeholderProfilePhoto)
	}

	shortCredentials, ok := responseObject["short_credentials"].(map[string]any)
	if !ok {
		t.Fatalf("short_credentials = %#v, want object", responseObject["short_credentials"])
	}
	if got := shortCredentials["id"]; got != placeholderShortCallID {
		t.Fatalf("short_credentials.id = %#v, want %q", got, placeholderShortCallID)
	}
	if got := shortCredentials["link_with_password"]; got != placeholderShortCallLinkWithPassword {
		t.Fatalf("short_credentials.link_with_password = %#v, want %q", got, placeholderShortCallLinkWithPassword)
	}
	if got := shortCredentials["link_without_password"]; got != placeholderShortCallLink {
		t.Fatalf("short_credentials.link_without_password = %#v, want %q", got, placeholderShortCallLink)
	}
	if got := shortCredentials["password"]; got != placeholderShortCallPassword {
		t.Fatalf("short_credentials.password = %#v, want %q", got, placeholderShortCallPassword)
	}
}
