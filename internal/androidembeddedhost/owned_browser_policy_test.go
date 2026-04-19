package androidembeddedhost

import (
	"testing"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
)

type fakeNonOwnedChallenge struct {
	provider string
	metadata provider.InteractiveChallengeMetadata
}

func (f fakeNonOwnedChallenge) ProviderName() string { return f.provider }
func (f fakeNonOwnedChallenge) StageName() string    { return "provider_resolve" }
func (f fakeNonOwnedChallenge) Kind() string         { return "browser" }
func (f fakeNonOwnedChallenge) Prompt() string       { return "return after browser" }
func (f fakeNonOwnedChallenge) OpenURL() string      { return "https://example.test/challenge" }
func (f fakeNonOwnedChallenge) ChallengeMetadata() provider.InteractiveChallengeMetadata {
	return f.metadata
}

func TestMobileProviderRegistryAdvertisesEmbeddedBrowserOnlyForApprovedProviders(t *testing.T) {
	registry := mobileProviderRegistry()

	vkDescriptor, err := registry.Descriptor("vk")
	if err != nil {
		t.Fatalf("Descriptor(vk) error = %v", err)
	}
	if vkDescriptor.BrowserPolicy != provider.ProviderBrowserPolicyEmbeddedAllowed {
		t.Fatalf("vk browser_policy = %q, want %q", vkDescriptor.BrowserPolicy, provider.ProviderBrowserPolicyEmbeddedAllowed)
	}

	genericDescriptor, err := registry.Descriptor("generic-turn")
	if err != nil {
		t.Fatalf("Descriptor(generic-turn) error = %v", err)
	}
	if genericDescriptor.BrowserPolicy != provider.ProviderBrowserPolicyNotRequired {
		t.Fatalf("generic-turn browser_policy = %q, want %q", genericDescriptor.BrowserPolicy, provider.ProviderBrowserPolicyNotRequired)
	}
}

func TestMobileChallengeMetadataOverridesApprovedOwnedBrowserChallenges(t *testing.T) {
	metadata := mobileChallengeMetadata(&vk.CaptchaChallenge{})
	if metadata.CompletionMode != provider.ChallengeCompletionModeOwnedBrowserObserved {
		t.Fatalf("completion_mode = %q, want %q", metadata.CompletionMode, provider.ChallengeCompletionModeOwnedBrowserObserved)
	}
	if !metadata.AllowRememberedSignIn {
		t.Fatal("allow_remembered_sign_in = false, want true")
	}
	if metadata.BrowserReturn != nil {
		t.Fatalf("browser_return = %#v, want nil", metadata.BrowserReturn)
	}
}

func TestMobileChallengeMetadataKeepsDefaultPathForNonOwnedChallenges(t *testing.T) {
	metadata := mobileChallengeMetadata(fakeNonOwnedChallenge{
		provider: "vk",
		metadata: provider.InteractiveChallengeMetadata{
			CompletionMode: provider.ChallengeCompletionModeAppReturnCallback,
			BrowserReturn: &provider.BrowserReturnMetadata{
				SignalKinds: []provider.BrowserReturnSignalKind{
					provider.BrowserReturnSignalKindForegroundResume,
				},
				AllowAutoContinue: true,
			},
		},
	})
	if metadata.CompletionMode != provider.ChallengeCompletionModeAppReturnCallback {
		t.Fatalf("completion_mode = %q, want %q", metadata.CompletionMode, provider.ChallengeCompletionModeAppReturnCallback)
	}
	if metadata.BrowserReturn == nil || !metadata.BrowserReturn.AllowAutoContinue {
		t.Fatalf("browser_return = %#v, want default app-return metadata", metadata.BrowserReturn)
	}
}
