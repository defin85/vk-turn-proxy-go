package vk

import (
	"context"
	"net/http"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

type httpDoer interface {
	Do(*http.Request) (*http.Response, error)
}

type Adapter struct {
	doer httpDoer
}

func New() *Adapter {
	return &Adapter{doer: newDefaultHTTPClient()}
}

func NewWithHTTPDoer(doer httpDoer) *Adapter {
	if doer == nil {
		doer = newDefaultHTTPClient()
	}

	return &Adapter{doer: doer}
}

func (a *Adapter) Name() string {
	return "vk"
}

func (a *Adapter) Descriptor() provider.ProviderDescriptor {
	return provider.ProviderDescriptor{
		ID:            "vk",
		DisplayName:   "VK Calls",
		Description:   "VK Calls invite or authenticated root start with browser-mediated continuation that resolves into transport-ready TURN credentials.",
		InputKind:     provider.ProviderInputKindLink,
		AuthPosture:   provider.ProviderAuthPostureGuestOrAccount,
		BrowserPolicy: provider.ProviderBrowserPolicyExternalRequired,
		ChallengeModes: []provider.ProviderChallengeMode{
			provider.ProviderChallengeModeBrowser,
		},
		ArtifactFamilies: []provider.ArtifactFamily{
			provider.ArtifactFamilyGenericTURN,
		},
		CapabilityHints: provider.ProviderCapabilityHints{
			PotentialActions: []provider.ArtifactAction{
				provider.ArtifactActionStartOnThisDevice,
				provider.ArtifactActionExportHandoff,
			},
			RedactionPolicy: provider.SummaryOnlyArtifactRedactionPolicy(),
		},
	}
}

func (a *Adapter) Resolve(ctx context.Context, link string) (provider.Resolution, error) {
	input, err := normalizeInput(link)
	if err != nil {
		return provider.Resolution{}, err
	}

	resolver := newResolver(a.doer)
	var resolution provider.Resolution
	switch input.family {
	case inputFamilyInvite:
		resolution, err = resolver.resolve(ctx, input.joinToken)
	case inputFamilyAuthenticatedRoot:
		resolution, err = resolver.resolveAuthenticatedHostedCall(
			ctx,
			input.normalizedLink,
		)
	default:
		err = provider.ErrNotImplemented
	}
	if err != nil {
		return provider.Resolution{}, err
	}

	if resolution.Metadata == nil {
		resolution.Metadata = make(map[string]string, 4)
	}
	resolution.Metadata["provider"] = "vk"
	if resolution.Metadata["resolution_method"] == "" {
		switch input.family {
		case inputFamilyAuthenticatedRoot:
			resolution.Metadata["resolution_method"] = "browser_observed"
		default:
			resolution.Metadata["resolution_method"] = "staged_http"
		}
	}
	applyDerivedTurnCredentialExpiry(&resolution, nowUTC())

	return resolution, nil
}
