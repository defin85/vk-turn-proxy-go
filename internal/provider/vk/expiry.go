package vk

import (
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
	"github.com/defin85/vk-turn-proxy-go/internal/turnrest"
)

const (
	metadataTurnCredentialExpirySource = "turn_credential_expiry_source"
	metadataTurnCredentialExpiresAt    = "turn_credential_expires_at"
	turnCredentialExpirySourceTURNREST = "turn_rest_username"
)

var nowUTC = func() time.Time {
	return time.Now().UTC()
}

func applyDerivedTurnCredentialExpiry(resolution *provider.Resolution, now time.Time) {
	if resolution == nil {
		return
	}

	candidate, ok := turnrest.ParseExpiryCandidate(resolution.Credentials.Username)
	if !ok {
		return
	}

	ttl := candidate.Expiry.Sub(now.UTC())
	if ttl < 0 {
		ttl = 0
	}
	resolution.Credentials.TTL = ttl

	if resolution.Metadata == nil {
		resolution.Metadata = make(map[string]string, 2)
	}
	resolution.Metadata[metadataTurnCredentialExpirySource] = turnCredentialExpirySourceTURNREST
	resolution.Metadata[metadataTurnCredentialExpiresAt] = candidate.Expiry.Format(time.RFC3339)
}
