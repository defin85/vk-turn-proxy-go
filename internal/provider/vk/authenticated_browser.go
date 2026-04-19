package vk

import "github.com/defin85/vk-turn-proxy-go/internal/provider"

const (
	authenticatedHostedCallRootURL                = "https://calls.vk.com/"
	stageAuthenticatedStartConversationCreateLink = "ok_start_conversation_create_join_link"
	authenticatedBrowserStartRequiredCode         = "authenticated_browser_start_required"
)

type authenticatedHostedCallChallenge struct {
	openURL string
}

func newAuthenticatedHostedCallChallenge(openURL string) *authenticatedHostedCallChallenge {
	if openURL == "" {
		openURL = authenticatedHostedCallRootURL
	}
	return &authenticatedHostedCallChallenge{openURL: openURL}
}

func (c *authenticatedHostedCallChallenge) ProviderName() string { return "vk" }

func (c *authenticatedHostedCallChallenge) StageName() string { return "provider_resolve" }

func (c *authenticatedHostedCallChallenge) Kind() string { return "browser" }

func (c *authenticatedHostedCallChallenge) Prompt() string {
	return "Authenticate in VK Calls and create a hosted call in the same browser session to continue provider resolution."
}

func (c *authenticatedHostedCallChallenge) OpenURL() string {
	if c == nil || c.openURL == "" {
		return authenticatedHostedCallRootURL
	}
	return c.openURL
}

func (c *authenticatedHostedCallChallenge) CookieURLs() []string {
	return []string{
		authenticatedHostedCallRootURL,
		"https://vk.com/",
		"https://login.vk.com/",
		"https://login.vk.ru/",
		"https://id.vk.ru/",
		"https://api.vk.com/",
	}
}

func (c *authenticatedHostedCallChallenge) BrowserStageObservations() []provider.BrowserStageObservation {
	return authenticatedHostedCallObservedStageObservations()
}

type authenticatedBrowserStartRequiredError struct {
	stageErr   *stageError
	challenge  *authenticatedHostedCallChallenge
	resumeHint string
}

func (e *authenticatedBrowserStartRequiredError) Error() string {
	if e == nil || e.stageErr == nil {
		return ""
	}
	if e.resumeHint == "" {
		return e.stageErr.Error()
	}
	return e.stageErr.Error() + ": " + e.resumeHint
}

func (e *authenticatedBrowserStartRequiredError) Unwrap() error {
	if e == nil {
		return nil
	}
	return e.stageErr
}

func (e *authenticatedBrowserStartRequiredError) Challenge() *authenticatedHostedCallChallenge {
	if e == nil {
		return nil
	}
	return e.challenge
}

func newAuthenticatedBrowserStartRequiredError(challenge *authenticatedHostedCallChallenge) error {
	return &authenticatedBrowserStartRequiredError{
		stageErr: &stageError{
			stage: "provider_resolve",
			code:  authenticatedBrowserStartRequiredCode,
			err:   errBrowserContinuationRequired,
		},
		challenge:  challenge,
		resumeHint: "continue inside the approved VK owned-browser flow and retry in interactive mode",
	}
}
