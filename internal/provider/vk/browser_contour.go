package vk

import (
	"errors"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	stageBrowserLoginAnonymTokenMessages = "vk_browser_login_anonym_token_messages"
	stageGetCallPreview                  = "vk_calls_get_call_preview"

	liveLoginAnonymTokenURL = "https://login.vk.com/?act=get_anonym_token"
	getCallPreviewURL       = "https://api.vk.com/method/calls.getCallPreview"

	browserPreviewOnlyCode     = "browser_preview_only"
	unsupportedLiveContourCode = "unsupported_live_contour"
)

func liveBrowserObservedStageObservations() []provider.BrowserStageObservation {
	return []provider.BrowserStageObservation{
		buildBrowserObservedStageObservation(stageGetAnonymousToken, "https://api.vk.com/method/calls.getAnonymousToken"),
		buildBrowserObservedStageObservation(stageBrowserLoginAnonymTokenMessages, liveLoginAnonymTokenURL),
		buildBrowserObservedStageObservation(stageGetCallPreview, getCallPreviewURL),
	}
}

func liveBrowserContinuationResults(continuation *provider.BrowserContinuation) []provider.BrowserStageResult {
	if continuation == nil || len(continuation.StageResults) == 0 {
		return nil
	}

	results := make([]provider.BrowserStageResult, 0, len(continuation.StageResults))
	for _, result := range continuation.StageResults {
		switch result.Stage {
		case stageBrowserLoginAnonymTokenMessages, stageGetCallPreview:
			results = append(results, result)
		}
	}

	return results
}

func liveBrowserStageDescriptor(stage string) (stageDescriptor, bool) {
	switch stage {
	case stageBrowserLoginAnonymTokenMessages:
		return stageDescriptor{
			name:        stageBrowserLoginAnonymTokenMessages,
			endpointURL: liveLoginAnonymTokenURL,
			redactedFields: []string{
				"client_secret",
			},
		}, true
	case stageGetCallPreview:
		return stageDescriptor{
			name:        stageGetCallPreview,
			endpointURL: getCallPreviewURL,
			redactedFields: []string{
				"access_token",
				"anonym_token",
				"anonymous_token",
				"vk_join_link",
				"join_link",
				"join_url",
			},
		}, true
	default:
		return stageDescriptor{}, false
	}
}

func (r *resolver) resolveAnonymousTokenFromBrowserContinuation(
	artifacts *artifactBuilder,
	legacyDescriptor stageDescriptor,
	continuation *provider.BrowserContinuation,
) (string, error) {
	if continuation == nil {
		artifacts.fail(stageGetAnonymousToken, browserContinuationFailedCode)
		return "", &provider.ArtifactError{
			Err: &stageError{
				stage: stageGetAnonymousToken,
				code:  browserContinuationFailedCode,
				err:   errors.New("browser continuation result is required"),
			},
			ProbeArtifact: artifacts.artifact,
		}
	}

	if liveResults := liveBrowserContinuationResults(continuation); len(liveResults) > 0 {
		return r.resolveLiveBrowserPreviewContour(artifacts, liveResults)
	}

	stageResult, ok := continuation.StageResult(stageGetAnonymousToken)
	if !ok || stageResult == nil {
		artifacts.fail(stageGetAnonymousToken, browserContinuationFailedCode)
		return "", &provider.ArtifactError{
			Err: &stageError{
				stage: stageGetAnonymousToken,
				code:  browserContinuationFailedCode,
				err:   errors.New("browser-observed continuation result is required"),
			},
			ProbeArtifact: artifacts.artifact,
		}
	}

	return r.resolveLegacyBrowserContinuationStage(artifacts, legacyDescriptor, *stageResult)
}

func (r *resolver) resolveLegacyBrowserContinuationStage(
	artifacts *artifactBuilder,
	descriptor stageDescriptor,
	stageResult provider.BrowserStageResult,
) (string, error) {
	browserStageArtifact, err := stageArtifactFromBrowserResult(descriptor, stageResult)
	if err != nil {
		artifacts.fail(stageGetAnonymousToken, browserContinuationFailedCode)
		return "", &provider.ArtifactError{
			Err: &stageError{
				stage: stageGetAnonymousToken,
				code:  browserContinuationFailedCode,
				err:   err,
			},
			ProbeArtifact: artifacts.artifact,
		}
	}
	if _, challengeAgain := parseCaptchaChallenge(stageResult.Body); challengeAgain {
		return "", artifacts.wrapError(
			&stageError{
				stage: stageGetAnonymousToken,
				code:  browserContinuationFailedCode,
				err:   errors.New("browser-observed stage 2 still requires captcha"),
			},
			withStageOutcome(browserStageArtifact, "provider_error", nil, browserContinuationFailedCode),
		)
	}

	anonymousToken, err := parseAnonymousToken(stageResult.Body)
	if err != nil {
		return "", artifacts.wrapError(
			&stageError{stage: stageGetAnonymousToken, code: browserContinuationFailedCode, err: err},
			withStageOutcome(browserStageArtifact, "provider_error", nil, browserContinuationFailedCode),
		)
	}
	artifacts.append(withStageOutcome(browserStageArtifact, "continue", map[string]any{
		"anonym_token": placeholderAnonymousToken,
	}, ""))

	return anonymousToken, nil
}

func (r *resolver) resolveLiveBrowserPreviewContour(
	artifacts *artifactBuilder,
	results []provider.BrowserStageResult,
) (string, error) {
	lastStage := stageGetAnonymousToken
	sawCallPreview := false

	for _, result := range results {
		descriptor, ok := liveBrowserStageDescriptor(result.Stage)
		if !ok {
			continue
		}

		stageArtifact, err := stageArtifactFromBrowserResult(descriptor, result)
		if err != nil {
			return "", artifacts.wrapError(
				&stageError{stage: result.Stage, code: unsupportedLiveContourCode, err: err},
				withStageOutcome(
					artifacts.newSyntheticStage(descriptor.name, descriptor.formKeys, descriptor.redactedFields),
					"provider_error",
					nil,
					unsupportedLiveContourCode,
				),
			)
		}

		lastStage = descriptor.name
		switch descriptor.name {
		case stageBrowserLoginAnonymTokenMessages:
			extracted := map[string]any{}
			if _, err := parseAccessToken(result.Body); err == nil {
				extracted["access_token"] = placeholderBrowserAccessToken
			}
			if len(extracted) == 0 {
				extracted = nil
			}
			artifacts.append(withStageOutcome(stageArtifact, "continue", extracted, ""))
		case stageGetCallPreview:
			sawCallPreview = true
			artifacts.append(withStageOutcome(stageArtifact, "provider_error", nil, browserPreviewOnlyCode))
		}
	}

	if sawCallPreview {
		artifacts.fail(stageGetCallPreview, browserPreviewOnlyCode)
		return "", &provider.ArtifactError{
			Err: &stageError{
				stage: stageGetCallPreview,
				code:  browserPreviewOnlyCode,
				err:   errors.New("live browser contour reached pre-join preview without normalized turn credentials"),
			},
			ProbeArtifact: artifacts.artifact,
		}
	}

	artifacts.fail(lastStage, unsupportedLiveContourCode)
	return "", &provider.ArtifactError{
		Err: &stageError{
			stage: lastStage,
			code:  unsupportedLiveContourCode,
			err:   errors.New("browser-observed live contour did not reach a transport-ready result"),
		},
		ProbeArtifact: artifacts.artifact,
	}
}
