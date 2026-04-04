package vk

import (
	"errors"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	placeholderInviteURL                 = "https://vk.com/call/join/<redacted:vk-join-token>"
	placeholderJoinToken                 = "<redacted:vk-join-token>"
	placeholderAccessToken1              = "<redacted:vk-access-token-1>"
	placeholderBrowserAccessToken        = "<redacted:vk-browser-access-token>"
	placeholderAnonymousToken            = "<redacted:vk-anonym-token>"
	placeholderSessionKey                = "<redacted:ok-session-key>"
	placeholderTurnUsername              = "<redacted:turn-username>"
	placeholderTurnPassword              = "<redacted:turn-password>"
	placeholderCaptchaURL                = "<redacted:vk-captcha-redirect-uri>"
	placeholderCaptchaImage              = "<redacted:vk-captcha-image-uri>"
	placeholderCaptchaSID                = "<redacted:vk-captcha-sid>"
	placeholderCaptchaKey                = "<redacted:vk-captcha-key>"
	placeholderCaptchaTS                 = "<redacted:vk-captcha-ts>"
	placeholderCaptchaAttempt            = "<redacted:vk-captcha-attempt>"
	placeholderSuccessToken              = "<redacted:vk-success-token>"
	placeholderRemixSTLID                = "<redacted:vk-remixstlid>"
	placeholderCallPreviewID             = "<redacted:vk-call-preview-id>"
	placeholderCallPreviewTitle          = "<redacted:vk-call-preview-title>"
	placeholderCallPreviewPhoto          = "<redacted:vk-call-preview-photo-uri>"
	placeholderProfileFirstName          = "<redacted:vk-profile-first-name>"
	placeholderProfileLastName           = "<redacted:vk-profile-last-name>"
	placeholderProfileID                 = "<redacted:vk-profile-id>"
	placeholderProfilePhoto              = "<redacted:vk-profile-photo-uri>"
	placeholderOKJoinLink                = "<redacted:vk-ok-join-link>"
	placeholderShortCallID               = "<redacted:vk-short-call-id>"
	placeholderShortCallLink             = "https://vk.com/call/<redacted:vk-short-call-id>"
	placeholderShortCallLinkWithPassword = "https://vk.com/call/<redacted:vk-short-call-id>?p=<redacted:vk-short-call-password>"
	placeholderShortCallPassword         = "<redacted:vk-short-call-password>"
)

type artifactBuilder struct {
	artifact *provider.ProbeArtifact
}

func newArtifactBuilder() *artifactBuilder {
	return &artifactBuilder{
		artifact: &provider.ProbeArtifact{
			Provider:         "vk",
			ResolutionMethod: "staged_http",
			Input: provider.ProbeArtifactInput{
				InviteURLRedacted:           placeholderInviteURL,
				NormalizedJoinTokenRedacted: placeholderJoinToken,
			},
		},
	}
}

func (b *artifactBuilder) append(stage provider.ProbeArtifactStage) {
	b.artifact.Stages = append(b.artifact.Stages, stage)
}

func (b *artifactBuilder) resolve(address string) {
	b.artifact.Outcome = provider.ProbeArtifactOutcome{
		ResultKind: "resolution",
		Resolution: &provider.ProbeArtifactResolution{
			UsernameRedacted: placeholderTurnUsername,
			PasswordRedacted: placeholderTurnPassword,
			Address:          address,
		},
	}
}

func (b *artifactBuilder) fail(stage string, code string) {
	b.artifact.Outcome = provider.ProbeArtifactOutcome{
		ResultKind: "provider_error",
		ProviderError: &provider.ProbeArtifactProviderError{
			Stage: stage,
			Code:  code,
		},
	}
}

func (b *artifactBuilder) newSyntheticStage(stage string, formKeys []string, redactedFields []string) provider.ProbeArtifactStage {
	return provider.ProbeArtifactStage{
		Name:       stage,
		EndpointID: stage,
		Request: provider.ProbeArtifactStageRequest{
			Method:         "POST",
			FormKeys:       formKeys,
			RedactedFields: redactedFields,
		},
		Response: provider.ProbeArtifactStageResponse{
			StatusCode: 0,
			Body: map[string]any{
				"error": "stage_not_executed",
			},
		},
	}
}

func (b *artifactBuilder) wrapError(err error, stage provider.ProbeArtifactStage) error {
	b.append(stage)

	var stageErr *stageError
	if errors.As(err, &stageErr) {
		b.fail(stageErr.stage, stageErr.code)
	}

	return &provider.ArtifactError{
		Err:           err,
		ProbeArtifact: b.artifact,
	}
}

func sanitizeResponseBody(stage string, payload map[string]any) map[string]any {
	switch stage {
	case stageLoginAnonymToken:
		return redactKeys(payload, map[string]string{
			"access_token": placeholderAccessToken1,
		})
	case stageBrowserLoginAnonymTokenMessages:
		return redactKeys(payload, map[string]string{
			"access_token":  placeholderBrowserAccessToken,
			"redirect_uri":  placeholderCaptchaURL,
			"captcha_img":   placeholderCaptchaImage,
			"captcha_sid":   placeholderCaptchaSID,
			"captcha_key":   placeholderCaptchaKey,
			"captcha_ts":    placeholderCaptchaTS,
			"success_token": placeholderSuccessToken,
			"remixstlid":    placeholderRemixSTLID,
			"vk_join_link":  placeholderInviteURL,
			"join_link":     placeholderInviteURL,
			"join_url":      placeholderInviteURL,
			"invite_url":    placeholderInviteURL,
		})
	case stageGetAnonymousToken:
		return redactKeys(payload, map[string]string{
			"vk_join_link":    placeholderInviteURL,
			"access_token":    placeholderAccessToken1,
			"token":           placeholderAnonymousToken,
			"redirect_uri":    placeholderCaptchaURL,
			"captcha_img":     placeholderCaptchaImage,
			"captcha_sid":     placeholderCaptchaSID,
			"captcha_key":     placeholderCaptchaKey,
			"captcha_ts":      placeholderCaptchaTS,
			"captcha_attempt": placeholderCaptchaAttempt,
			"success_token":   placeholderSuccessToken,
			"remixstlid":      placeholderRemixSTLID,
		})
	case stageGetCallPreview:
		return sanitizeCallPreviewResponseBody(redactKeys(payload, map[string]string{
			"vk_join_link":    placeholderInviteURL,
			"join_link":       placeholderInviteURL,
			"join_url":        placeholderInviteURL,
			"invite_url":      placeholderInviteURL,
			"access_token":    placeholderBrowserAccessToken,
			"anonym_token":    placeholderAnonymousToken,
			"anonymous_token": placeholderAnonymousToken,
			"token":           placeholderAnonymousToken,
			"redirect_uri":    placeholderCaptchaURL,
			"captcha_img":     placeholderCaptchaImage,
			"captcha_sid":     placeholderCaptchaSID,
			"captcha_key":     placeholderCaptchaKey,
			"captcha_ts":      placeholderCaptchaTS,
			"success_token":   placeholderSuccessToken,
			"remixstlid":      placeholderRemixSTLID,
		}))
	case stageOKAnonymLogin:
		return redactKeys(payload, map[string]string{
			"session_key": placeholderSessionKey,
		})
	case stageJoinConversationByURL:
		return redactKeys(payload, map[string]string{
			"username":   placeholderTurnUsername,
			"credential": placeholderTurnPassword,
		})
	default:
		return map[string]any{}
	}
}

func sanitizeCallPreviewResponseBody(payload map[string]any) map[string]any {
	response, ok := payload["response"].(map[string]any)
	if !ok || response == nil {
		return payload
	}

	response["call_id"] = placeholderCallPreviewID
	response["title"] = placeholderCallPreviewTitle
	response["ok_join_link"] = placeholderOKJoinLink

	if _, ok := response["photo_400"]; ok {
		response["photo_400"] = placeholderCallPreviewPhoto
	}
	if _, ok := response["photo_base"]; ok {
		response["photo_base"] = placeholderCallPreviewPhoto
	}

	if shortCredentials, ok := response["short_credentials"].(map[string]any); ok && shortCredentials != nil {
		shortCredentials["id"] = placeholderShortCallID
		shortCredentials["link_with_password"] = placeholderShortCallLinkWithPassword
		shortCredentials["link_without_password"] = placeholderShortCallLink
		shortCredentials["password"] = placeholderShortCallPassword
	}

	if profiles, ok := response["profiles"].([]any); ok {
		for _, rawProfile := range profiles {
			profile, ok := rawProfile.(map[string]any)
			if !ok || profile == nil {
				continue
			}
			profile["id"] = placeholderProfileID
			profile["first_name"] = placeholderProfileFirstName
			profile["last_name"] = placeholderProfileLastName
			if _, ok := profile["photo_200"]; ok {
				profile["photo_200"] = placeholderProfilePhoto
			}
			if _, ok := profile["photo_base"]; ok {
				profile["photo_base"] = placeholderProfilePhoto
			}
		}
	}

	return payload
}

func redactKeys(value any, replacements map[string]string) map[string]any {
	redacted, ok := redactValue(value, replacements).(map[string]any)
	if !ok || redacted == nil {
		return map[string]any{}
	}

	return redacted
}

func redactValue(value any, replacements map[string]string) any {
	switch typed := value.(type) {
	case map[string]any:
		result := make(map[string]any, len(typed))
		keyName, hasKeyName := typed["key"].(string)
		for key, inner := range typed {
			if key == "value" && hasKeyName {
				if replacement, ok := replacements[keyName]; ok {
					result[key] = replacement
					continue
				}
			}
			if replacement, ok := replacements[key]; ok {
				result[key] = replacement
				continue
			}
			result[key] = redactValue(inner, replacements)
		}
		return result
	case []any:
		result := make([]any, 0, len(typed))
		for _, inner := range typed {
			result = append(result, redactValue(inner, replacements))
		}
		return result
	default:
		return value
	}
}

func withStageOutcome(stage provider.ProbeArtifactStage, kind string, extracted map[string]any, errorCode string) provider.ProbeArtifactStage {
	stage.Outcome = provider.ProbeArtifactStageOutcome{
		Kind:      kind,
		Extracted: extracted,
		ErrorCode: errorCode,
	}

	return stage
}
