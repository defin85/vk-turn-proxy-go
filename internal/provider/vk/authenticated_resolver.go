package vk

import (
	"context"
	"errors"
	"net/http"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	authenticatedBrowserContinuationFailedCode = "authenticated_browser_continuation_failed"
	authenticatedBrowserContourIncompleteCode  = "authenticated_browser_contour_incomplete"
	authenticatedBrowserUnsupportedContourCode = "authenticated_browser_unsupported_contour"
)

var errBrowserContinuationRequired = errors.New("browser continuation result is required")

func authenticatedHostedCallObservedStageObservations() []provider.BrowserStageObservation {
	return []provider.BrowserStageObservation{
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
			Stage:     stageAuthenticatedStartConversationCreateLink,
			Method:    http.MethodPost,
			URLPrefix: okAPIURL,
			RequiredFormKeys: []string{
				"session_key",
			},
			RequiredFormValues: map[string]string{
				"method":          "vchat.startConversation",
				"format":          "JSON",
				"application_key": okApplicationKey,
				"createJoinLink":  "true",
			},
		},
	}
}

func authenticatedBrowserContinuationResults(
	continuation *provider.BrowserContinuation,
) []provider.BrowserStageResult {
	if continuation == nil || len(continuation.StageResults) == 0 {
		return nil
	}

	results := make([]provider.BrowserStageResult, 0, len(continuation.StageResults))
	for _, result := range continuation.StageResults {
		switch result.Stage {
		case stageOKAnonymLogin, stageAuthenticatedStartConversationCreateLink:
			results = append(results, result)
		}
	}

	return results
}

func authenticatedBrowserStageDescriptor(stage string) (stageDescriptor, bool) {
	switch stage {
	case stageOKAnonymLogin:
		return stageDescriptor{
			name:        stageOKAnonymLogin,
			endpointURL: okAPIURL,
			redactedFields: []string{
				"session_data",
			},
		}, true
	case stageAuthenticatedStartConversationCreateLink:
		return stageDescriptor{
			name:        stageAuthenticatedStartConversationCreateLink,
			endpointURL: okAPIURL,
			redactedFields: []string{
				"session_key",
			},
		}, true
	default:
		return stageDescriptor{}, false
	}
}

func (r *resolver) resolveAuthenticatedHostedCall(
	ctx context.Context,
	startURL string,
) (provider.Resolution, error) {
	artifacts := newAuthenticatedArtifactBuilder(startURL)
	challenge := newAuthenticatedHostedCallChallenge(startURL)
	challengeStage := withStageOutcome(
		artifacts.newSyntheticStage(challenge.StageName(), nil, nil),
		"provider_error",
		nil,
		authenticatedBrowserStartRequiredCode,
	)

	browserHandler := provider.BrowserContinuationHandlerFromContext(ctx)
	if browserHandler == nil {
		return provider.Resolution{}, artifacts.wrapError(
			newAuthenticatedBrowserStartRequiredError(challenge),
			challengeStage,
		)
	}

	continuation, err := browserHandler.Continue(ctx, challenge)
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(
			&stageError{
				stage: challenge.StageName(),
				code:  authenticatedBrowserContinuationFailedCode,
				err:   err,
			},
			withStageOutcome(
				artifacts.newSyntheticStage(challenge.StageName(), nil, nil),
				"provider_error",
				nil,
				authenticatedBrowserContinuationFailedCode,
			),
		)
	}

	return r.resolveAuthenticatedHostedCallFromBrowserContinuation(
		artifacts,
		continuation,
	)
}

func (r *resolver) resolveAuthenticatedHostedCallFromBrowserContinuation(
	artifacts *artifactBuilder,
	continuation *provider.BrowserContinuation,
) (provider.Resolution, error) {
	results := authenticatedBrowserContinuationResults(continuation)
	if len(results) == 0 {
		return provider.Resolution{}, artifacts.wrapError(
			&stageError{
				stage: "provider_resolve",
				code:  authenticatedBrowserContourIncompleteCode,
				err:   errBrowserContinuationRequired,
			},
			withStageOutcome(
				artifacts.newSyntheticStage("provider_resolve", nil, nil),
				"provider_error",
				nil,
				authenticatedBrowserContourIncompleteCode,
			),
		)
	}

	sawAnonymLogin := false
	lastStage := "provider_resolve"

	for _, result := range results {
		descriptor, ok := authenticatedBrowserStageDescriptor(result.Stage)
		if !ok {
			continue
		}

		stageArtifact, err := stageArtifactFromBrowserResult(descriptor, result)
		if err != nil {
			return provider.Resolution{}, artifacts.wrapError(
				&stageError{
					stage: descriptor.name,
					code:  authenticatedBrowserUnsupportedContourCode,
					err:   err,
				},
				withStageOutcome(
					artifacts.newSyntheticStage(
						descriptor.name,
						descriptor.formKeys,
						descriptor.redactedFields,
					),
					"provider_error",
					nil,
					authenticatedBrowserUnsupportedContourCode,
				),
			)
		}

		lastStage = descriptor.name
		switch descriptor.name {
		case stageOKAnonymLogin:
			sawAnonymLogin = true
			extracted := map[string]any{}
			if _, err := parseSessionKey(result.Body); err == nil {
				extracted["session_key"] = placeholderSessionKey
			}
			if len(extracted) == 0 {
				extracted = nil
			}
			artifacts.append(withStageOutcome(stageArtifact, "continue", extracted, ""))
		case stageAuthenticatedStartConversationCreateLink:
			if !sawAnonymLogin {
				return provider.Resolution{}, artifacts.wrapError(
					&stageError{
						stage: descriptor.name,
						code:  authenticatedBrowserUnsupportedContourCode,
						err:   errors.New("authenticated hosted-call contour reached transport stage before auth.anonymLogin"),
					},
					withStageOutcome(
						stageArtifact,
						"provider_error",
						nil,
						authenticatedBrowserUnsupportedContourCode,
					),
				)
			}

			username, password, address, err := parseHostedCallTransportCredentials(
				result.Body,
			)
			if err != nil {
				return provider.Resolution{}, artifacts.wrapError(
					&stageError{
						stage: descriptor.name,
						code:  authenticatedBrowserContourIncompleteCode,
						err:   err,
					},
					withStageOutcome(
						stageArtifact,
						"provider_error",
						nil,
						authenticatedBrowserContourIncompleteCode,
					),
				)
			}

			artifacts.append(withStageOutcome(stageArtifact, "resolution", map[string]any{
				"username":           placeholderTurnUsername,
				"credential":         placeholderTurnPassword,
				"normalized_address": address,
			}, ""))
			artifacts.resolve(address)

			return provider.Resolution{
				Credentials: provider.Credentials{
					Username: username,
					Password: password,
					Address:  address,
					TTL:      0,
				},
				Artifact: artifacts.artifact,
			}, nil
		}
	}

	return provider.Resolution{}, artifacts.wrapError(
		&stageError{
			stage: lastStage,
			code:  authenticatedBrowserContourIncompleteCode,
			err:   errors.New("authenticated browser contour did not reach transport-ready hosted-call data"),
		},
		withStageOutcome(
			artifacts.newSyntheticStage(lastStage, nil, nil),
			"provider_error",
			nil,
			authenticatedBrowserContourIncompleteCode,
		),
	)
}
