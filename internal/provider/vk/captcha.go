package vk

import (
	"errors"
	"fmt"
	"strings"
)

const captchaRequiredCode = "captcha_required"
const browserContinuationFailedCode = "browser_continuation_failed"

type CaptchaChallenge struct {
	stage       string
	redirectURL string
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
