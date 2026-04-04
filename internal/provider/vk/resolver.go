package vk

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"net/url"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const (
	stageLoginAnonymToken      = "vk_login_anonym_token"
	stageGetAnonymousToken     = "vk_calls_get_anonymous_token"
	stageOKAnonymLogin         = "ok_anonym_login"
	stageJoinConversationByURL = "ok_join_conversation_by_link"

	loginAnonymTokenURL  = "https://login.vk.ru/?act=get_anonym_token"
	getAnonymousTokenURL = "https://api.vk.ru/method/calls.getAnonymousToken?v=5.274&client_id=6287487"
	okAPIURL             = "https://calls.okcdn.ru/fb.do"

	vkClientID       = "6287487"
	vkClientSecret   = "QbYic1K3lEV5kTGiqlq2"
	okApplicationKey = "CGMMEJLGDIHBABABA"
	userAgent        = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:144.0) Gecko/20100101 Firefox/144.0"
)

type resolver struct {
	doer httpDoer
}

type stageDescriptor struct {
	name           string
	endpointURL    string
	formKeys       []string
	redactedFields []string
}

type stageError struct {
	stage string
	code  string
	err   error
}

func (e *stageError) Error() string {
	if e.err == nil {
		return fmt.Sprintf("vk stage %s [%s]", e.stage, e.code)
	}

	return fmt.Sprintf("vk stage %s [%s]: %v", e.stage, e.code, e.err)
}

func (e *stageError) Unwrap() error {
	return e.err
}

func newResolver(doer httpDoer) *resolver {
	if doer == nil {
		doer = newDefaultHTTPClient()
	}

	return &resolver{doer: doer}
}

func (r *resolver) resolve(ctx context.Context, joinToken string) (provider.Resolution, error) {
	artifacts := newArtifactBuilder()

	loginStage := stageDescriptor{
		name:        stageLoginAnonymToken,
		endpointURL: loginAnonymTokenURL,
		formKeys:    []string{"client_id", "token_type", "client_secret", "version", "app_id"},
		redactedFields: []string{
			"client_secret",
		},
	}
	accessTokenPayload, accessTokenArtifact, err := r.performStage(ctx, loginStage, url.Values{
		"client_id":     {vkClientID},
		"token_type":    {"messages"},
		"client_secret": {vkClientSecret},
		"version":       {"1"},
		"app_id":        {vkClientID},
	})
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(err, accessTokenArtifact)
	}

	accessToken, err := parseAccessToken(accessTokenPayload)
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(
			&stageError{stage: stageLoginAnonymToken, code: "missing_access_token", err: err},
			withStageOutcome(accessTokenArtifact, "provider_error", nil, "missing_access_token"),
		)
	}
	artifacts.append(withStageOutcome(accessTokenArtifact, "continue", map[string]any{
		"access_token": placeholderAccessToken1,
	}, ""))

	anonymousTokenStage := stageDescriptor{
		name:        stageGetAnonymousToken,
		endpointURL: getAnonymousTokenURL,
		formKeys:    []string{"vk_join_link", "name", "access_token"},
		redactedFields: []string{
			"vk_join_link",
			"access_token",
		},
	}
	anonymousToken, err := r.resolveAnonymousToken(ctx, artifacts, joinToken, accessToken, anonymousTokenStage)
	if err != nil {
		return provider.Resolution{}, err
	}

	deviceID, err := newDeviceID()
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(
			&stageError{stage: stageOKAnonymLogin, code: "generate_device_id", err: err},
			withStageOutcome(
				artifacts.newSyntheticStage(stageOKAnonymLogin, []string{"session_data", "method", "format", "application_key"}, []string{"session_data"}),
				"provider_error",
				nil,
				"generate_device_id",
			),
		)
	}

	sessionData, err := json.Marshal(map[string]any{
		"version":        2,
		"device_id":      deviceID,
		"client_version": 1.1,
		"client_type":    "SDK_JS",
	})
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(
			&stageError{stage: stageOKAnonymLogin, code: "encode_session_data", err: err},
			withStageOutcome(
				artifacts.newSyntheticStage(stageOKAnonymLogin, []string{"session_data", "method", "format", "application_key"}, []string{"session_data"}),
				"provider_error",
				nil,
				"encode_session_data",
			),
		)
	}

	okLoginStage := stageDescriptor{
		name:        stageOKAnonymLogin,
		endpointURL: okAPIURL,
		formKeys:    []string{"session_data", "method", "format", "application_key"},
		redactedFields: []string{
			"session_data",
		},
	}
	sessionPayload, sessionArtifact, err := r.performStage(ctx, okLoginStage, url.Values{
		"session_data":    {string(sessionData)},
		"method":          {"auth.anonymLogin"},
		"format":          {"JSON"},
		"application_key": {okApplicationKey},
	})
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(err, sessionArtifact)
	}

	sessionKey, err := parseSessionKey(sessionPayload)
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(
			&stageError{stage: stageOKAnonymLogin, code: "missing_session_key", err: err},
			withStageOutcome(sessionArtifact, "provider_error", nil, "missing_session_key"),
		)
	}
	artifacts.append(withStageOutcome(sessionArtifact, "continue", map[string]any{
		"session_key": placeholderSessionKey,
	}, ""))

	joinStage := stageDescriptor{
		name:        stageJoinConversationByURL,
		endpointURL: okAPIURL,
		formKeys:    []string{"joinLink", "isVideo", "protocolVersion", "anonymToken", "method", "format", "application_key", "session_key"},
		redactedFields: []string{
			"joinLink",
			"anonymToken",
			"session_key",
		},
	}
	turnPayload, turnArtifact, err := r.performStage(ctx, joinStage, url.Values{
		"joinLink":        {joinToken},
		"isVideo":         {"false"},
		"protocolVersion": {"5"},
		"anonymToken":     {anonymousToken},
		"method":          {"vchat.joinConversationByLink"},
		"format":          {"JSON"},
		"application_key": {okApplicationKey},
		"session_key":     {sessionKey},
	})
	if err != nil {
		return provider.Resolution{}, artifacts.wrapError(err, turnArtifact)
	}

	username, password, address, err := parseTurnCredentials(turnPayload)
	if err != nil {
		code := "invalid_turn_payload"
		switch {
		case errors.Is(err, errMissingTurnUsername):
			code = "missing_turn_username"
		case errors.Is(err, errMissingTurnCredential):
			code = "missing_turn_credential"
		case errors.Is(err, errMissingTurnURL):
			code = "missing_turn_url"
		case errors.Is(err, errInvalidTurnURL):
			code = "invalid_turn_url"
		}

		return provider.Resolution{}, artifacts.wrapError(
			&stageError{stage: stageJoinConversationByURL, code: code, err: err},
			withStageOutcome(turnArtifact, "provider_error", nil, code),
		)
	}
	artifacts.append(withStageOutcome(turnArtifact, "resolution", map[string]any{
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

func (r *resolver) resolveAnonymousToken(
	ctx context.Context,
	artifacts *artifactBuilder,
	joinToken string,
	accessToken string,
	descriptor stageDescriptor,
) (string, error) {
	form := url.Values{
		"vk_join_link": {"https://vk.com/call/join/" + joinToken},
		"name":         {"123"},
		"access_token": {accessToken},
	}
	inviteURL := "https://vk.com/call/join/" + joinToken

	for {
		payload, stageArtifact, err := r.performStage(ctx, descriptor, form)
		if err != nil {
			return "", artifacts.wrapError(err, stageArtifact)
		}

		if challenge, ok := parseCaptchaChallenge(payload); ok {
			challenge.browserOpenURL = inviteURL
			challenge.stageObservations = liveBrowserObservedStageObservations()
			challengeStage := withStageOutcome(stageArtifact, "provider_error", nil, captchaRequiredCode)
			browserHandler := provider.BrowserContinuationHandlerFromContext(ctx)
			if browserHandler == nil {
				return "", artifacts.wrapError(newCaptchaRequiredError(stageGetAnonymousToken, challenge, nil), challengeStage)
			}
			artifacts.append(challengeStage)
			continuation, err := browserHandler.Continue(ctx, challenge)
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
			return r.resolveAnonymousTokenFromBrowserContinuation(artifacts, descriptor, continuation)
		}

		anonymousToken, err := parseAnonymousToken(payload)
		if err != nil {
			return "", artifacts.wrapError(
				&stageError{stage: stageGetAnonymousToken, code: "missing_anonymous_token", err: err},
				withStageOutcome(stageArtifact, "provider_error", nil, "missing_anonymous_token"),
			)
		}
		artifacts.append(withStageOutcome(stageArtifact, "continue", map[string]any{
			"anonym_token": placeholderAnonymousToken,
		}, ""))

		return anonymousToken, nil
	}
}

func stageArtifactFromBrowserResult(descriptor stageDescriptor, result provider.BrowserStageResult) (provider.ProbeArtifactStage, error) {
	if result.StatusCode == 0 {
		return provider.ProbeArtifactStage{}, errors.New("browser-observed stage response status is required")
	}
	if result.Body == nil {
		return provider.ProbeArtifactStage{}, errors.New("browser-observed stage response body is required")
	}

	return provider.ProbeArtifactStage{
		Name:       descriptor.name,
		EndpointID: descriptor.name,
		Request: provider.ProbeArtifactStageRequest{
			Method:         http.MethodPost,
			FormKeys:       browserStageFormKeys(descriptor, result),
			RedactedFields: browserStageRedactedFields(descriptor, result),
		},
		Response: provider.ProbeArtifactStageResponse{
			StatusCode: result.StatusCode,
			Body:       sanitizeResponseBody(descriptor.name, result.Body),
		},
	}, nil
}

func browserStageFormKeys(descriptor stageDescriptor, result provider.BrowserStageResult) []string {
	if len(result.FormKeys) == 0 {
		return descriptor.formKeys
	}

	keys := make([]string, 0, len(result.FormKeys))
	keys = append(keys, result.FormKeys...)
	return keys
}

func browserStageRedactedFields(descriptor stageDescriptor, result provider.BrowserStageResult) []string {
	keys := make([]string, 0, len(descriptor.redactedFields)+4)
	keys = append(keys, descriptor.redactedFields...)

	extra := map[string]struct{}{
		"captcha_sid":     {},
		"captcha_key":     {},
		"captcha_ts":      {},
		"captcha_attempt": {},
		"success_token":   {},
	}
	seen := make(map[string]struct{}, len(keys))
	for _, key := range keys {
		seen[key] = struct{}{}
	}
	for _, key := range result.FormKeys {
		if _, ok := extra[key]; !ok {
			continue
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		keys = append(keys, key)
	}

	return keys
}
