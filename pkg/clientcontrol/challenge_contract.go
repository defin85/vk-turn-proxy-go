package clientcontrol

import (
	"strings"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/providerprompt"
)

func newChallengeRecord(
	id string,
	sessionID string,
	resolutionID string,
	challenge provider.InteractiveChallenge,
	now time.Time,
) Challenge {
	completionMode, browserReturn, ownedBrowser := challengeContractMetadata(
		challenge,
	)
	return Challenge{
		ID:             id,
		SessionID:      sessionID,
		ResolutionID:   resolutionID,
		Provider:       challenge.ProviderName(),
		Stage:          challenge.StageName(),
		Kind:           challenge.Kind(),
		Prompt:         providerprompt.ContinuationPrompt(challenge),
		OpenURL:        providerprompt.ContinuationOpenURL(challenge),
		Status:         ChallengeStatusPending,
		CompletionMode: completionMode,
		BrowserReturn:  browserReturn,
		OwnedBrowser:   ownedBrowser,
		CreatedAt:      now,
		UpdatedAt:      now,
	}
}

func challengeContractMetadata(
	challenge provider.InteractiveChallenge,
) (
	ChallengeCompletionMode,
	*ChallengeBrowserReturnMetadata,
	*ChallengeOwnedBrowserMetadata,
) {
	return challengeContractMetadataFromProviderMetadata(
		challenge,
		defaultInteractiveChallengeMetadata(challenge),
	)
}

func challengeContractMetadataWithMetadata(
	challenge provider.InteractiveChallenge,
	metadata provider.InteractiveChallengeMetadata,
) (
	ChallengeCompletionMode,
	*ChallengeBrowserReturnMetadata,
	*ChallengeOwnedBrowserMetadata,
) {
	if challenge == nil {
		return ChallengeCompletionModeManualConfirm, nil, nil
	}

	switch metadata.CompletionMode {
	case provider.ChallengeCompletionModeManualConfirm:
		return ChallengeCompletionModeManualConfirm, nil, nil
	case provider.ChallengeCompletionModeOwnedBrowserObserved:
		ownedBrowser := normalizeOwnedBrowserMetadata(challenge, metadata)
		if ownedBrowser == nil {
			return ChallengeCompletionModeManualConfirm, nil, nil
		}
		return ChallengeCompletionModeOwnedBrowserObserved, nil, ownedBrowser
	case provider.ChallengeCompletionModeAppReturnCallback:
		browserReturn := normalizeAppReturnMetadata(metadata.BrowserReturn)
		if browserReturn == nil {
			return ChallengeCompletionModeManualConfirm, nil, nil
		}
		return ChallengeCompletionModeAppReturnCallback, browserReturn, nil
	default:
		return ChallengeCompletionModeManualConfirm, nil, nil
	}
}

func challengeContractMetadataFromProviderMetadata(
	challenge provider.InteractiveChallenge,
	metadata provider.InteractiveChallengeMetadata,
) (
	ChallengeCompletionMode,
	*ChallengeBrowserReturnMetadata,
	*ChallengeOwnedBrowserMetadata,
) {
	return challengeContractMetadataWithMetadata(challenge, metadata)
}

func defaultInteractiveChallengeMetadata(
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

func normalizeAppReturnMetadata(
	metadata *provider.BrowserReturnMetadata,
) *ChallengeBrowserReturnMetadata {
	if metadata == nil || !metadata.AllowAutoContinue {
		return nil
	}

	signalKinds := normalizeBrowserReturnSignalKinds(metadata.SignalKinds)
	if len(signalKinds) == 0 {
		return nil
	}

	returnMetadata := &ChallengeBrowserReturnMetadata{
		SignalKinds:       signalKinds,
		AllowAutoContinue: true,
	}
	if expectedReturnURI := strings.TrimSpace(metadata.ExpectedReturnURI); expectedReturnURI != "" {
		returnMetadata.ExpectedReturnURI = expectedReturnURI
	}
	return returnMetadata
}

func normalizeOwnedBrowserMetadata(
	challenge provider.InteractiveChallenge,
	metadata provider.InteractiveChallengeMetadata,
) *ChallengeOwnedBrowserMetadata {
	cookieURLs := providerprompt.ContinuationCookieURLs(challenge)
	if len(cookieURLs) == 0 {
		return nil
	}

	return &ChallengeOwnedBrowserMetadata{
		CookieURLs:     append([]string(nil), cookieURLs...),
		RememberSignIn: metadata.AllowRememberedSignIn,
	}
}

func normalizeBrowserReturnSignalKinds(
	signalKinds []provider.BrowserReturnSignalKind,
) []BrowserReturnSignalKind {
	if len(signalKinds) == 0 {
		return nil
	}

	seen := make(map[BrowserReturnSignalKind]struct{}, len(signalKinds))
	out := make([]BrowserReturnSignalKind, 0, len(signalKinds))
	for _, signalKind := range signalKinds {
		normalized, ok := mapBrowserReturnSignalKind(signalKind)
		if !ok {
			continue
		}
		if _, exists := seen[normalized]; exists {
			continue
		}
		seen[normalized] = struct{}{}
		out = append(out, normalized)
	}
	if len(out) == 0 {
		return nil
	}
	return out
}

func mapBrowserReturnSignalKind(
	signalKind provider.BrowserReturnSignalKind,
) (BrowserReturnSignalKind, bool) {
	switch signalKind {
	case provider.BrowserReturnSignalKindAppLink:
		return BrowserReturnSignalKindAppLink, true
	case provider.BrowserReturnSignalKindUniversalLink:
		return BrowserReturnSignalKindUniversalLink, true
	case provider.BrowserReturnSignalKindForegroundResume:
		return BrowserReturnSignalKindForegroundResume, true
	default:
		return "", false
	}
}
