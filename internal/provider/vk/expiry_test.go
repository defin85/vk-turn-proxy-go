package vk

import (
	"testing"
	"time"

	"github.com/defin85/vk-turn-proxy-go/internal/provider"
)

func TestApplyDerivedTurnCredentialExpiryAddsTTLAndMetadata(t *testing.T) {
	t.Parallel()

	resolution := &provider.Resolution{
		Credentials: provider.Credentials{
			Username: "1775852226:584771567964",
		},
	}

	applyDerivedTurnCredentialExpiry(resolution, time.Date(2026, time.April, 10, 12, 17, 29, 0, time.UTC))

	wantTTL := 7*time.Hour + 59*time.Minute + 37*time.Second
	if resolution.Credentials.TTL != wantTTL {
		t.Fatalf("resolution.Credentials.TTL = %s, want %s", resolution.Credentials.TTL, wantTTL)
	}
	if got := resolution.Metadata[metadataTurnCredentialExpirySource]; got != turnCredentialExpirySourceTURNREST {
		t.Fatalf("resolution.Metadata[%q] = %q, want %q", metadataTurnCredentialExpirySource, got, turnCredentialExpirySourceTURNREST)
	}
	if got := resolution.Metadata[metadataTurnCredentialExpiresAt]; got != "2026-04-10T20:17:06Z" {
		t.Fatalf("resolution.Metadata[%q] = %q, want %q", metadataTurnCredentialExpiresAt, got, "2026-04-10T20:17:06Z")
	}
}

func TestApplyDerivedTurnCredentialExpiryIgnoresUnknownUsernameFormat(t *testing.T) {
	t.Parallel()

	resolution := &provider.Resolution{
		Credentials: provider.Credentials{
			Username: "<redacted:turn-username>",
		},
		Metadata: map[string]string{
			"provider": "vk",
		},
	}

	applyDerivedTurnCredentialExpiry(resolution, time.Date(2026, time.April, 10, 12, 17, 29, 0, time.UTC))

	if resolution.Credentials.TTL != 0 {
		t.Fatalf("resolution.Credentials.TTL = %s, want 0", resolution.Credentials.TTL)
	}
	if got := resolution.Metadata[metadataTurnCredentialExpirySource]; got != "" {
		t.Fatalf("resolution.Metadata[%q] = %q, want empty", metadataTurnCredentialExpirySource, got)
	}
	if got := resolution.Metadata[metadataTurnCredentialExpiresAt]; got != "" {
		t.Fatalf("resolution.Metadata[%q] = %q, want empty", metadataTurnCredentialExpiresAt, got)
	}
}

func TestApplyDerivedTurnCredentialExpiryClampsExpiredCredentials(t *testing.T) {
	t.Parallel()

	resolution := &provider.Resolution{
		Credentials: provider.Credentials{
			Username: "1712745600:alice",
		},
	}

	applyDerivedTurnCredentialExpiry(resolution, time.Date(2026, time.April, 10, 12, 17, 29, 0, time.UTC))

	if resolution.Credentials.TTL != 0 {
		t.Fatalf("resolution.Credentials.TTL = %s, want 0", resolution.Credentials.TTL)
	}
	if got := resolution.Metadata[metadataTurnCredentialExpirySource]; got != turnCredentialExpirySourceTURNREST {
		t.Fatalf("resolution.Metadata[%q] = %q, want %q", metadataTurnCredentialExpirySource, got, turnCredentialExpirySourceTURNREST)
	}
}
