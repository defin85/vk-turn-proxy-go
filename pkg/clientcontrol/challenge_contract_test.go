package clientcontrol

import (
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestChallengeContractMetadataFailsClosedOnInvalidAppReturnMetadata(t *testing.T) {
	testCases := []struct {
		name     string
		metadata provider.InteractiveChallengeMetadata
	}{
		{
			name: "missing browser return metadata",
			metadata: provider.InteractiveChallengeMetadata{
				CompletionMode: provider.ChallengeCompletionModeAppReturnCallback,
			},
		},
		{
			name: "auto continue disabled",
			metadata: provider.InteractiveChallengeMetadata{
				CompletionMode: provider.ChallengeCompletionModeAppReturnCallback,
				BrowserReturn: &provider.BrowserReturnMetadata{
					SignalKinds: []provider.BrowserReturnSignalKind{
						provider.BrowserReturnSignalKindForegroundResume,
					},
				},
			},
		},
		{
			name: "no supported signal kinds",
			metadata: provider.InteractiveChallengeMetadata{
				CompletionMode: provider.ChallengeCompletionModeAppReturnCallback,
				BrowserReturn: &provider.BrowserReturnMetadata{
					SignalKinds:       []provider.BrowserReturnSignalKind{"future_signal"},
					AllowAutoContinue: true,
				},
			},
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			mode, browserReturn, ownedBrowser := challengeContractMetadata(
				fakeChallenge{metadata: tc.metadata},
			)
			if mode != ChallengeCompletionModeManualConfirm {
				t.Fatalf("completion mode = %q, want %q", mode, ChallengeCompletionModeManualConfirm)
			}
			if browserReturn != nil {
				t.Fatalf("browser_return = %#v, want nil", browserReturn)
			}
			if ownedBrowser != nil {
				t.Fatalf("owned_browser = %#v, want nil", ownedBrowser)
			}
		})
	}
}

func TestChallengeContractMetadataFailsClosedOnMissingOwnedBrowserMetadata(t *testing.T) {
	mode, browserReturn, ownedBrowser := challengeContractMetadata(
		fakeOwnedBrowserChallenge{
			fakeChallenge: fakeChallenge{
				metadata: provider.InteractiveChallengeMetadata{
					CompletionMode: provider.ChallengeCompletionModeOwnedBrowserObserved,
				},
			},
		},
	)
	if mode != ChallengeCompletionModeManualConfirm {
		t.Fatalf("completion mode = %q, want %q", mode, ChallengeCompletionModeManualConfirm)
	}
	if browserReturn != nil {
		t.Fatalf("browser_return = %#v, want nil", browserReturn)
	}
	if ownedBrowser != nil {
		t.Fatalf("owned_browser = %#v, want nil", ownedBrowser)
	}
}

func TestChallengeContractMetadataExposesOwnedBrowserCookieURLs(t *testing.T) {
	mode, browserReturn, ownedBrowser := challengeContractMetadata(
		fakeOwnedBrowserChallenge{
			fakeChallenge: fakeChallenge{
				metadata: provider.InteractiveChallengeMetadata{
					CompletionMode: provider.ChallengeCompletionModeOwnedBrowserObserved,
				},
			},
			cookieURLs: []string{
				"https://login.vk.ru/",
				"https://api.vk.ru/",
			},
		},
	)
	if mode != ChallengeCompletionModeOwnedBrowserObserved {
		t.Fatalf("completion mode = %q, want %q", mode, ChallengeCompletionModeOwnedBrowserObserved)
	}
	if browserReturn != nil {
		t.Fatalf("browser_return = %#v, want nil", browserReturn)
	}
	if ownedBrowser == nil {
		t.Fatal("owned_browser = nil, want metadata")
	}
	if got := ownedBrowser.CookieURLs; len(got) != 2 ||
		got[0] != "https://login.vk.ru/" ||
		got[1] != "https://api.vk.ru/" {
		t.Fatalf("owned_browser.cookie_urls = %#v, want login/api urls", got)
	}
}
