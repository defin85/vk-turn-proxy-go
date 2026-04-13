package vk

import (
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestCaptchaChallengeMetadataUsesForegroundResumeAutoContinue(t *testing.T) {
	challenge := &CaptchaChallenge{
		stage:       stageGetAnonymousToken,
		redirectURL: "https://login.vk.example.test/captcha",
	}

	metadata := challenge.ChallengeMetadata()
	if metadata.CompletionMode != provider.ChallengeCompletionModeAppReturnCallback {
		t.Fatalf("completion mode = %q, want %q", metadata.CompletionMode, provider.ChallengeCompletionModeAppReturnCallback)
	}
	if metadata.BrowserReturn == nil {
		t.Fatal("browser return metadata = nil, want metadata")
	}
	if !metadata.BrowserReturn.AllowAutoContinue {
		t.Fatal("browser return allow_auto_continue = false, want true")
	}
	if metadata.BrowserReturn.ExpectedReturnURI != "" {
		t.Fatalf("browser return expected_return_uri = %q, want empty", metadata.BrowserReturn.ExpectedReturnURI)
	}
	if got := metadata.BrowserReturn.SignalKinds; len(got) != 1 || got[0] != provider.BrowserReturnSignalKindForegroundResume {
		t.Fatalf("browser return signal_kinds = %#v, want foreground_resume", got)
	}
}
