package vk

import (
	"errors"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	placeholderInviteURL      = "https://vk.com/call/join/<redacted:vk-join-token>"
	placeholderJoinToken      = "<redacted:vk-join-token>"
	placeholderAccessToken1   = "<redacted:vk-access-token-1>"
	placeholderAnonymousToken = "<redacted:vk-anonym-token>"
	placeholderSessionKey     = "<redacted:ok-session-key>"
	placeholderTurnUsername   = "<redacted:turn-username>"
	placeholderTurnPassword   = "<redacted:turn-password>"
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
		b.artifact.Outcome = provider.ProbeArtifactOutcome{
			ResultKind: "provider_error",
			ProviderError: &provider.ProbeArtifactProviderError{
				Stage: stageErr.stage,
				Code:  stageErr.code,
			},
		}
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
	case stageGetAnonymousToken:
		return redactKeys(payload, map[string]string{
			"token": placeholderAnonymousToken,
		})
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
		for key, inner := range typed {
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
