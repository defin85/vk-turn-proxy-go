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
			mode, browserReturn := challengeContractMetadata(fakeChallenge{metadata: tc.metadata})
			if mode != ChallengeCompletionModeManualConfirm {
				t.Fatalf("completion mode = %q, want %q", mode, ChallengeCompletionModeManualConfirm)
			}
			if browserReturn != nil {
				t.Fatalf("browser_return = %#v, want nil", browserReturn)
			}
		})
	}
}
