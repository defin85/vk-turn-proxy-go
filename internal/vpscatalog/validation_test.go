package vpscatalog

import (
	"errors"
	"testing"
	"time"
)

func TestValidateSnapshotRejectsWrongAudienceRollbackAndUnsigned(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	base := testSnapshot(now)

	tests := []struct {
		name   string
		mutate func(CatalogSnapshot) CatalogSnapshot
		opts   ValidationOptions
		want   ValidationStatus
	}{
		{
			name: "wrong audience",
			mutate: func(snapshot CatalogSnapshot) CatalogSnapshot {
				snapshot.Audience = "other-client"
				return AttachIntegrity(snapshot, "test")
			},
			opts: ValidationOptions{
				Now:                now,
				ExpectedAudience:   "relay-client",
				ExpectedIssuer:     "vk-turn-proxy-go",
				ExpectedEndpointID: "vps-main",
				RequireSigned:      true,
			},
			want: ValidationStatusWrongAudience,
		},
		{
			name:   "rollback",
			mutate: func(snapshot CatalogSnapshot) CatalogSnapshot { return AttachIntegrity(snapshot, "test") },
			opts: ValidationOptions{
				Now:                       now,
				ExpectedAudience:          "relay-client",
				ExpectedIssuer:            "vk-turn-proxy-go",
				ExpectedEndpointID:        "vps-main",
				HighestAcceptedGeneration: 3,
				RequireSigned:             true,
			},
			want: ValidationStatusRollback,
		},
		{
			name:   "unsigned",
			mutate: func(snapshot CatalogSnapshot) CatalogSnapshot { return snapshot },
			opts: ValidationOptions{
				Now:                now,
				ExpectedAudience:   "relay-client",
				ExpectedIssuer:     "vk-turn-proxy-go",
				ExpectedEndpointID: "vps-main",
				RequireSigned:      true,
			},
			want: ValidationStatusUnsigned,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := ValidateSnapshot(tt.mutate(base), tt.opts)
			if !errors.Is(err, ErrValidationFailed) {
				t.Fatalf("ValidateSnapshot() error = %v, want ErrValidationFailed", err)
			}
			if result.Status != tt.want {
				t.Fatalf("ValidateSnapshot().status = %q, want %q", result.Status, tt.want)
			}
		})
	}
}

func TestValidateOfferReadinessDistinguishesMissingEvidenceAndDegraded(t *testing.T) {
	now := time.Date(2026, 5, 3, 12, 0, 0, 0, time.UTC)
	source := testSnapshot(now).Sources[0]
	offer := source.ArtifactOffers[0]

	missing := source
	missing.Evidence = nil
	result := ValidateOfferReadiness(missing, offer, now)
	if result.Status != ValidationStatusMissingEvidence {
		t.Fatalf("missing evidence readiness = %q, want %q", result.Status, ValidationStatusMissingEvidence)
	}

	degraded := source
	degraded.Health.Status = HealthStatusDegraded
	degraded.Health.DegradedReason = "throughput_ceiling"
	result = ValidateOfferReadiness(degraded, offer, now)
	if result.Status != ValidationStatusDegraded {
		t.Fatalf("degraded readiness = %q, want %q", result.Status, ValidationStatusDegraded)
	}
}

func testSnapshot(now time.Time) CatalogSnapshot {
	evidenceExpires := now.Add(5 * time.Minute)
	return CatalogSnapshot{
		Version:     SchemaVersion,
		GeneratedAt: now,
		ExpiresAt:   now.Add(10 * time.Minute),
		Issuer:      "vk-turn-proxy-go",
		Audience:    "relay-client",
		EndpointID:  "vps-main",
		Generation:  2,
		Sources: []ProviderSource{{
			ID:           "managed-turn",
			ProviderID:   "generic-turn",
			DisplayName:  "Managed TURN",
			SourceFamily: "managed_turn",
			Health: Health{
				Status:    HealthStatusHealthy,
				ExpiresAt: &evidenceExpires,
			},
			Evidence: []Evidence{{
				Kind:      "synthetic_probe",
				Status:    EvidenceStatusFresh,
				ExpiresAt: &evidenceExpires,
			}},
			ArtifactOffers: []ArtifactOffer{{
				ID:            "turn-handoff",
				Family:        "generic_turn",
				AccessMethods: []string{"turn_credentials"},
				Actions:       []string{"start_on_this_device", "export_handoff"},
				MaxTTLSeconds: 60,
				Health: Health{
					Status:    HealthStatusHealthy,
					ExpiresAt: &evidenceExpires,
				},
				Evidence: []Evidence{{
					Kind:      "remote_ingress_probe",
					Status:    EvidenceStatusFresh,
					ExpiresAt: &evidenceExpires,
				}},
				Redaction: DefaultRedactionPolicy(),
			}},
		}},
	}
}
