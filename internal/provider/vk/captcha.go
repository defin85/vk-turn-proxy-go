package vk

import (
	"errors"
	"fmt"
	"net/http"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

const captchaRequiredCode = "captcha_required"
const browserContinuationFailedCode = "browser_continuation_failed"

type CaptchaChallenge struct {
	stage             string
	redirectURL       string
	browserOpenURL    string
	stageRequests     []provider.BrowserStageRequest
	stageObservations []provider.BrowserStageObservation
}

func (c *CaptchaChallenge) ProviderName() string {
	return "vk"
}

func (c *CaptchaChallenge) StageName() string {
	return c.stage
}

func (c *CaptchaChallenge) Kind() string {
	return "captcha"
}

func (c *CaptchaChallenge) Prompt() string {
	return "VK requires a manual captcha challenge before invite resolution can continue."
}

func (c *CaptchaChallenge) OpenURL() string {
	if strings.TrimSpace(c.browserOpenURL) != "" {
		return c.browserOpenURL
	}
	return c.redirectURL
}

func (c *CaptchaChallenge) CookieURLs() []string {
	return []string{
		c.redirectURL,
		"https://id.vk.ru/",
		"https://vk.com/",
		"https://api.vk.ru/",
		"https://login.vk.ru/",
	}
}

func (c *CaptchaChallenge) BrowserStageRequests() []provider.BrowserStageRequest {
	if c == nil {
		return nil
	}

	result := make([]provider.BrowserStageRequest, 0, len(c.stageRequests))
	for _, request := range c.stageRequests {
		cloned := provider.BrowserStageRequest{
			Stage:  request.Stage,
			Method: request.Method,
			URL:    request.URL,
		}
		if len(request.Form) > 0 {
			cloned.Form = make(map[string]string, len(request.Form))
			for key, value := range request.Form {
				cloned.Form[key] = value
			}
		}
		result = append(result, cloned)
	}

	return result
}

func (c *CaptchaChallenge) BrowserStageObservations() []provider.BrowserStageObservation {
	if c == nil {
		return nil
	}

	result := make([]provider.BrowserStageObservation, 0, len(c.stageObservations))
	for _, observation := range c.stageObservations {
		result = append(result, provider.BrowserStageObservation{
			Stage:     observation.Stage,
			Method:    observation.Method,
			URLPrefix: observation.URLPrefix,
		})
	}

	return result
}

type CaptchaRequiredError struct {
	stageErr   *stageError
	challenge  *CaptchaChallenge
	resumeHint string
}

func (e *CaptchaRequiredError) Error() string {
	if e == nil || e.stageErr == nil {
		return ""
	}
	if strings.TrimSpace(e.resumeHint) == "" {
		return e.stageErr.Error()
	}

	return fmt.Sprintf("%s: %s", e.stageErr.Error(), e.resumeHint)
}

func (e *CaptchaRequiredError) Unwrap() error {
	if e == nil {
		return nil
	}

	return e.stageErr
}

func (e *CaptchaRequiredError) Challenge() *CaptchaChallenge {
	if e == nil {
		return nil
	}

	return e.challenge
}

func parseCaptchaChallenge(payload map[string]any) (*CaptchaChallenge, bool) {
	errorObject, err := objectField(payload, "error")
	if err != nil {
		return nil, false
	}

	errorCode, err := numericField(errorObject, "error_code")
	if err != nil || errorCode != 14 {
		return nil, false
	}

	redirectURL, err := stringField(errorObject, "redirect_uri")
	if err != nil {
		return nil, false
	}

	return &CaptchaChallenge{
		stage:       stageGetAnonymousToken,
		redirectURL: redirectURL,
	}, true
}

func buildBrowserOwnedStageRequest(descriptor stageDescriptor, form map[string]string) provider.BrowserStageRequest {
	clonedForm := make(map[string]string, len(form))
	for key, value := range form {
		clonedForm[key] = value
	}

	return provider.BrowserStageRequest{
		Stage:  descriptor.name,
		Method: http.MethodPost,
		URL:    descriptor.endpointURL,
		Form:   clonedForm,
	}
}

func buildBrowserObservedStageObservation(stage string, urlPrefix string) provider.BrowserStageObservation {
	return provider.BrowserStageObservation{
		Stage:     stage,
		Method:    http.MethodPost,
		URLPrefix: urlPrefix,
	}
}

func newCaptchaRequiredError(stage string, challenge *CaptchaChallenge, err error) error {
	if err == nil {
		err = errors.New("vk captcha required")
	}

	return &CaptchaRequiredError{
		stageErr: &stageError{
			stage: stage,
			code:  captchaRequiredCode,
			err:   err,
		},
		challenge:  challenge,
		resumeHint: "complete the VK captcha challenge and retry in interactive mode",
	}
}
