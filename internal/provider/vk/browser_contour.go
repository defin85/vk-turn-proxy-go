package vk

import (
	"errors"
	"net/http"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	stageBrowserLoginAnonymTokenMessages = "vk_browser_login_anonym_token_messages"
	stageGetCallPreview                  = "vk_calls_get_call_preview"

	liveLoginAnonymTokenURL = "https://login.vk.com/?act=get_anonym_token"
	getCallPreviewURL       = "https://api.vk.com/method/calls.getCallPreview"

	browserPreviewOnlyCode            = "browser_preview_only"
	browserPostPreviewUnsupportedCode = "browser_post_preview_unsupported"
	unsupportedLiveContourCode        = "unsupported_live_contour"
)

func liveBrowserObservedStageObservations(joinToken string) []provider.BrowserStageObservation {
	inviteURL := "https://vk.com/call/join/" + joinToken

	return []provider.BrowserStageObservation{
		buildBrowserObservedStageObservation(stageGetAnonymousToken, "https://api.vk.com/method/calls.getAnonymousToken"),
		buildBrowserObservedStageObservation(stageBrowserLoginAnonymTokenMessages, liveLoginAnonymTokenURL),
		buildBrowserObservedStageObservation(stageGetCallPreview, getCallPreviewURL),
		{
			Stage:     stageOKAnonymLogin,
			Method:    http.MethodPost,
			URLPrefix: okAPIURL,
			RequiredFormKeys: []string{
				"session_data",
			},
			RequiredFormValues: map[string]string{
				"method":          "auth.anonymLogin",
				"format":          "JSON",
				"application_key": okApplicationKey,
			},
		},
		{
			Stage:     stageJoinConversationByURL,
			Method:    http.MethodPost,
			URLPrefix: okAPIURL,
			RequiredFormKeys: []string{
				"anonymToken",
				"session_key",
			},
			RequiredFormValues: map[string]string{
				"method":          "vchat.joinConversationByLink",
				"format":          "JSON",
				"application_key": okApplicationKey,
				"protocolVersion": "5",
				"isVideo":         "false",
			},
			RequiredFormValueAlternatives: map[string][]string{
				"joinLink": {joinToken, inviteURL},
			},
		},
	}
}

func liveBrowserContinuationResults(continuation *provider.BrowserContinuation) []provider.BrowserStageResult {
	if continuation == nil || len(continuation.StageResults) == 0 {
		return nil
	}

	results := make([]provider.BrowserStageResult, 0, len(continuation.StageResults))
	for _, result := range continuation.StageResults {
		switch result.Stage {
		case stageBrowserLoginAnonymTokenMessages, stageGetCallPreview, stageOKAnonymLogin, stageJoinConversationByURL:
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
	case stageOKAnonymLogin:
		return stageDescriptor{
			name:        stageOKAnonymLogin,
			endpointURL: okAPIURL,
			redactedFields: []string{
				"session_data",
			},
		}, true
	case stageJoinConversationByURL:
		return stageDescriptor{
			name:        stageJoinConversationByURL,
			endpointURL: okAPIURL,
			redactedFields: []string{
				"joinLink",
				"anonymToken",
				"session_key",
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
) (anonymousTokenResolution, error) {
	if continuation == nil {
		artifacts.fail(stageGetAnonymousToken, browserContinuationFailedCode)
		return anonymousTokenResolution{}, &provider.ArtifactError{
			Err: &stageError{
				stage: stageGetAnonymousToken,
				code:  browserContinuationFailedCode,
				err:   errors.New("browser continuation result is required"),
			},
			ProbeArtifact: artifacts.artifact,
		}
	}

	stageResult, ok := continuation.StageResult(stageGetAnonymousToken)
	liveResults := liveBrowserContinuationResults(continuation)
	if len(liveResults) > 0 && hasLivePreviewOrPostPreviewResults(liveResults) {
		return r.resolveLiveBrowserPreviewContour(artifacts, liveResults)
	}
	if len(liveResults) > 0 && ok && stageResult != nil {
		if err := appendLivePrePreviewArtifacts(artifacts, liveResults); err != nil {
			return anonymousTokenResolution{}, err
		}
	}

	if !ok || stageResult == nil {
		if len(liveResults) > 0 {
			return r.resolveLiveBrowserPreviewContour(artifacts, liveResults)
		}
		artifacts.fail(stageGetAnonymousToken, browserContinuationFailedCode)
		return anonymousTokenResolution{}, &provider.ArtifactError{
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
) (anonymousTokenResolution, error) {
	browserStageArtifact, err := stageArtifactFromBrowserResult(descriptor, stageResult)
	if err != nil {
		artifacts.fail(stageGetAnonymousToken, browserContinuationFailedCode)
		return anonymousTokenResolution{}, &provider.ArtifactError{
			Err: &stageError{
				stage: stageGetAnonymousToken,
				code:  browserContinuationFailedCode,
				err:   err,
			},
			ProbeArtifact: artifacts.artifact,
		}
	}
	if _, challengeAgain := parseCaptchaChallenge(stageResult.Body); challengeAgain {
		return anonymousTokenResolution{}, artifacts.wrapError(
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
		return anonymousTokenResolution{}, artifacts.wrapError(
			&stageError{stage: stageGetAnonymousToken, code: browserContinuationFailedCode, err: err},
			withStageOutcome(browserStageArtifact, "provider_error", nil, browserContinuationFailedCode),
		)
	}
	artifacts.append(withStageOutcome(browserStageArtifact, "continue", map[string]any{
		"anonym_token": placeholderAnonymousToken,
	}, ""))

	return anonymousTokenResolution{anonymousToken: anonymousToken}, nil
}

func (r *resolver) resolveLiveBrowserPreviewContour(
	artifacts *artifactBuilder,
	results []provider.BrowserStageResult,
) (anonymousTokenResolution, error) {
	lastStage := stageGetAnonymousToken
	sawCallPreview := false
	sawPostPreview := false

	for i, result := range results {
		descriptor, ok := liveBrowserStageDescriptor(result.Stage)
		if !ok {
			continue
		}

		stageArtifact, err := stageArtifactFromBrowserResult(descriptor, result)
		if err != nil {
			return anonymousTokenResolution{}, artifacts.wrapError(
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
			if hasObservedPostPreviewResult(results, i+1) {
				artifacts.append(withStageOutcome(stageArtifact, "continue", nil, ""))
				continue
			}
			artifacts.append(withStageOutcome(stageArtifact, "provider_error", nil, browserPreviewOnlyCode))
		case stageOKAnonymLogin:
			if !sawCallPreview {
				return anonymousTokenResolution{}, artifacts.wrapError(
					&stageError{stage: stageOKAnonymLogin, code: unsupportedLiveContourCode, err: errors.New("browser-observed post-preview stage appeared before preview")},
					withStageOutcome(stageArtifact, "provider_error", nil, unsupportedLiveContourCode),
				)
			}
			sawPostPreview = true
			extracted := map[string]any{}
			if _, err := parseSessionKey(result.Body); err == nil {
				extracted["session_key"] = placeholderSessionKey
			}
			if len(extracted) == 0 {
				extracted = nil
			}
			if hasObservedPostPreviewResult(results, i+1) {
				artifacts.append(withStageOutcome(stageArtifact, "continue", extracted, ""))
				continue
			}
			artifacts.append(withStageOutcome(stageArtifact, "provider_error", nil, browserPostPreviewUnsupportedCode))
		case stageJoinConversationByURL:
			if !sawCallPreview {
				return anonymousTokenResolution{}, artifacts.wrapError(
					&stageError{stage: stageJoinConversationByURL, code: unsupportedLiveContourCode, err: errors.New("browser-observed post-preview stage appeared before preview")},
					withStageOutcome(stageArtifact, "provider_error", nil, unsupportedLiveContourCode),
				)
			}
			sawPostPreview = true
			username, password, address, err := parseTurnCredentials(result.Body)
			if err != nil {
				return anonymousTokenResolution{}, artifacts.wrapError(
					&stageError{stage: stageJoinConversationByURL, code: browserPostPreviewUnsupportedCode, err: err},
					withStageOutcome(stageArtifact, "provider_error", nil, browserPostPreviewUnsupportedCode),
				)
			}
			artifacts.append(withStageOutcome(stageArtifact, "resolution", map[string]any{
				"username":           placeholderTurnUsername,
				"credential":         placeholderTurnPassword,
				"normalized_address": address,
			}, ""))
			artifacts.resolve(address)

			return anonymousTokenResolution{
				resolution: &provider.Resolution{
					Credentials: provider.Credentials{
						Username: username,
						Password: password,
						Address:  address,
						TTL:      0,
					},
					Artifact: artifacts.artifact,
				},
			}, nil
		}
	}

	if sawCallPreview {
		if sawPostPreview {
			artifacts.fail(lastStage, browserPostPreviewUnsupportedCode)
			return anonymousTokenResolution{}, &provider.ArtifactError{
				Err: &stageError{
					stage: lastStage,
					code:  browserPostPreviewUnsupportedCode,
					err:   errors.New("browser-observed post-preview contour did not yield normalized turn credentials"),
				},
				ProbeArtifact: artifacts.artifact,
			}
		}
		artifacts.fail(stageGetCallPreview, browserPreviewOnlyCode)
		return anonymousTokenResolution{}, &provider.ArtifactError{
			Err: &stageError{
				stage: stageGetCallPreview,
				code:  browserPreviewOnlyCode,
				err:   errors.New("live browser contour reached pre-join preview without normalized turn credentials"),
			},
			ProbeArtifact: artifacts.artifact,
		}
	}

	artifacts.fail(lastStage, unsupportedLiveContourCode)
	return anonymousTokenResolution{}, &provider.ArtifactError{
		Err: &stageError{
			stage: lastStage,
			code:  unsupportedLiveContourCode,
			err:   errors.New("browser-observed live contour did not reach a transport-ready result"),
		},
		ProbeArtifact: artifacts.artifact,
	}
}

func hasObservedPostPreviewResult(results []provider.BrowserStageResult, start int) bool {
	for i := start; i < len(results); i++ {
		if isObservedPostPreviewStage(results[i].Stage) {
			return true
		}
	}

	return false
}

func isObservedPostPreviewStage(stage string) bool {
	switch stage {
	case stageOKAnonymLogin, stageJoinConversationByURL:
		return true
	default:
		return false
	}
}

func hasLivePreviewOrPostPreviewResults(results []provider.BrowserStageResult) bool {
	for _, result := range results {
		if result.Stage == stageGetCallPreview || isObservedPostPreviewStage(result.Stage) {
			return true
		}
	}

	return false
}

func appendLivePrePreviewArtifacts(artifacts *artifactBuilder, results []provider.BrowserStageResult) error {
	for _, result := range results {
		if result.Stage != stageBrowserLoginAnonymTokenMessages {
			continue
		}

		descriptor, ok := liveBrowserStageDescriptor(result.Stage)
		if !ok {
			continue
		}
		stageArtifact, err := stageArtifactFromBrowserResult(descriptor, result)
		if err != nil {
			return artifacts.wrapError(
				&stageError{stage: result.Stage, code: unsupportedLiveContourCode, err: err},
				withStageOutcome(
					artifacts.newSyntheticStage(descriptor.name, descriptor.formKeys, descriptor.redactedFields),
					"provider_error",
					nil,
					unsupportedLiveContourCode,
				),
			)
		}

		extracted := map[string]any{}
		if _, err := parseAccessToken(result.Body); err == nil {
			extracted["access_token"] = placeholderBrowserAccessToken
		}
		if len(extracted) == 0 {
			extracted = nil
		}
		artifacts.append(withStageOutcome(stageArtifact, "continue", extracted, ""))
	}

	return nil
}
