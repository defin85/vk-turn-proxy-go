package androidembeddedhost

import (
	"context"
	"strings"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/genericturn"
	"github.com/defin85/vk-turn-proxy-go/internal/provider/vk"
)

func mobileProviderRegistry() *provider.Registry {
	return provider.NewRegistry(
		genericturn.New(),
		mobileOwnedBrowserAdapter{base: vk.New()},
	)
}

func mobileChallengeMetadata(
	challenge provider.InteractiveChallenge,
) provider.InteractiveChallengeMetadata {
	metadata := defaultChallengeMetadata(challenge)
	if challenge == nil {
		return metadata
	}
	if !mobileOwnedBrowserProviderApproved(challenge.ProviderName()) {
		return metadata
	}
	if _, ok := challenge.(provider.BrowserOwnedStageChallenge); !ok {
		return metadata
	}
	return provider.InteractiveChallengeMetadata{
		CompletionMode:        provider.ChallengeCompletionModeOwnedBrowserObserved,
		AllowRememberedSignIn: true,
	}
}

func defaultChallengeMetadata(
	challenge provider.InteractiveChallenge,
) provider.InteractiveChallengeMetadata {
	if challenge == nil {
		return provider.InteractiveChallengeMetadata{
			CompletionMode: provider.ChallengeCompletionModeManualConfirm,
		}
	}
	metadataProvider, ok := challenge.(provider.InteractiveChallengeMetadataProvider)
	if !ok {
		return provider.InteractiveChallengeMetadata{
			CompletionMode: provider.ChallengeCompletionModeManualConfirm,
		}
	}
	return metadataProvider.ChallengeMetadata()
}

func mobileOwnedBrowserProviderApproved(providerName string) bool {
	switch strings.TrimSpace(strings.ToLower(providerName)) {
	case "vk":
		return true
	default:
		return false
	}
}

type mobileOwnedBrowserAdapter struct {
	base provider.Adapter
}

func (a mobileOwnedBrowserAdapter) Name() string {
	return a.base.Name()
}

func (a mobileOwnedBrowserAdapter) Descriptor() provider.ProviderDescriptor {
	descriptor := a.base.Descriptor()
	if mobileOwnedBrowserProviderApproved(descriptor.ID) {
		descriptor.BrowserPolicy = provider.ProviderBrowserPolicyEmbeddedAllowed
	}
	return descriptor
}

func (a mobileOwnedBrowserAdapter) Resolve(
	ctx context.Context,
	link string,
) (provider.Resolution, error) {
	return a.base.Resolve(ctx, link)
}
