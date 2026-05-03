package vpscatalog

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

var ErrValidationFailed = errors.New("vps provider catalog validation failed")

type ValidationOptions struct {
	Now                       time.Time
	ExpectedIssuer            string
	ExpectedAudience          string
	ExpectedEndpointID        string
	HighestAcceptedGeneration uint64
	RequireSigned             bool
}

type ValidationResult struct {
	Status  ValidationStatus `json:"status"`
	Reason  string           `json:"reason,omitempty"`
	Message string           `json:"message,omitempty"`
}

type ValidationError struct {
	Result ValidationResult
}

func (e *ValidationError) Error() string {
	if e == nil {
		return ""
	}
	if e.Result.Message != "" {
		return e.Result.Message
	}
	return string(e.Result.Status)
}

func (e *ValidationError) Is(target error) bool {
	return target == ErrValidationFailed
}

func ValidateSnapshot(snapshot CatalogSnapshot, opts ValidationOptions) (ValidationResult, error) {
	now := opts.Now.UTC()
	if now.IsZero() {
		now = time.Now().UTC()
	}
	fail := func(status ValidationStatus, reason string, format string, args ...any) (ValidationResult, error) {
		result := ValidationResult{
			Status:  status,
			Reason:  reason,
			Message: strings.TrimSpace(fmt.Sprintf(format, args...)),
		}
		return result, &ValidationError{Result: result}
	}

	if strings.TrimSpace(snapshot.Version) != SchemaVersion {
		return fail(
			ValidationStatusUnsupported,
			"unsupported_schema",
			"catalog schema version %q is unsupported",
			snapshot.Version,
		)
	}
	if strings.TrimSpace(snapshot.Issuer) == "" {
		return fail(ValidationStatusInvalid, "issuer_missing", "catalog issuer is required")
	}
	if opts.ExpectedIssuer != "" && snapshot.Issuer != opts.ExpectedIssuer {
		return fail(
			ValidationStatusWrongIssuer,
			"issuer_mismatch",
			"catalog issuer %q does not match expected issuer %q",
			snapshot.Issuer,
			opts.ExpectedIssuer,
		)
	}
	if strings.TrimSpace(snapshot.Audience) == "" {
		return fail(ValidationStatusInvalid, "audience_missing", "catalog audience is required")
	}
	if opts.ExpectedAudience != "" && snapshot.Audience != opts.ExpectedAudience {
		return fail(
			ValidationStatusWrongAudience,
			"audience_mismatch",
			"catalog audience %q does not match expected audience %q",
			snapshot.Audience,
			opts.ExpectedAudience,
		)
	}
	if strings.TrimSpace(snapshot.EndpointID) == "" {
		return fail(ValidationStatusInvalid, "endpoint_missing", "catalog endpoint_id is required")
	}
	if opts.ExpectedEndpointID != "" && snapshot.EndpointID != opts.ExpectedEndpointID {
		return fail(
			ValidationStatusWrongEndpoint,
			"endpoint_mismatch",
			"catalog endpoint_id %q does not match expected endpoint_id %q",
			snapshot.EndpointID,
			opts.ExpectedEndpointID,
		)
	}
	if snapshot.Generation == 0 {
		return fail(ValidationStatusInvalid, "generation_missing", "catalog generation is required")
	}
	if opts.HighestAcceptedGeneration > 0 && snapshot.Generation < opts.HighestAcceptedGeneration {
		return fail(
			ValidationStatusRollback,
			"generation_rollback",
			"catalog generation %d is below highest accepted generation %d",
			snapshot.Generation,
			opts.HighestAcceptedGeneration,
		)
	}
	if snapshot.GeneratedAt.IsZero() {
		return fail(ValidationStatusInvalid, "generated_at_missing", "catalog generated_at is required")
	}
	if snapshot.ExpiresAt.IsZero() {
		return fail(ValidationStatusInvalid, "expires_at_missing", "catalog expires_at is required")
	}
	if !snapshot.ExpiresAt.After(now) {
		return fail(
			ValidationStatusStale,
			"snapshot_expired",
			"catalog expired at %s",
			snapshot.ExpiresAt.UTC().Format(time.RFC3339),
		)
	}
	if opts.RequireSigned {
		if snapshot.Integrity.Mode != IntegrityModeSignedSnapshotV1 ||
			strings.TrimSpace(snapshot.Integrity.Digest) == "" ||
			strings.TrimSpace(snapshot.Integrity.Signature) == "" {
			return fail(ValidationStatusUnsigned, "snapshot_unsigned", "catalog snapshot is not signed")
		}
		if digest := SnapshotDigest(snapshot); digest != snapshot.Integrity.Digest {
			return fail(ValidationStatusUnsigned, "snapshot_digest_mismatch", "catalog snapshot digest does not match integrity metadata")
		}
	}
	for _, source := range snapshot.Sources {
		if err := validateSourceShape(source); err != nil {
			return fail(ValidationStatusInvalid, "source_invalid", err.Error())
		}
	}

	return ValidationResult{Status: ValidationStatusValid}, nil
}

func validateSourceShape(source ProviderSource) error {
	if strings.TrimSpace(source.ID) == "" {
		return errors.New("catalog source id is required")
	}
	if strings.TrimSpace(source.ProviderID) == "" {
		return fmt.Errorf("catalog source %q provider_id is required", source.ID)
	}
	for _, offer := range source.ArtifactOffers {
		if strings.TrimSpace(offer.ID) == "" {
			return fmt.Errorf("catalog source %q has an artifact offer without id", source.ID)
		}
		if strings.TrimSpace(offer.Family) == "" {
			return fmt.Errorf("catalog source %q offer %q family is required", source.ID, offer.ID)
		}
		if len(offer.AccessMethods) == 0 {
			return fmt.Errorf("catalog source %q offer %q access_methods are required", source.ID, offer.ID)
		}
		if len(offer.Actions) == 0 {
			return fmt.Errorf("catalog source %q offer %q actions are required", source.ID, offer.ID)
		}
	}
	return nil
}

func ValidateOfferReadiness(source ProviderSource, offer ArtifactOffer, now time.Time) ValidationResult {
	now = now.UTC()
	if now.IsZero() {
		now = time.Now().UTC()
	}
	if status := healthValidationStatus(source.Health, now); status != ValidationStatusValid {
		return ValidationResult{Status: status, Reason: "source_health", Message: sourceHealthMessage(source, status)}
	}
	if status := healthValidationStatus(offer.Health, now); status != ValidationStatusValid {
		return ValidationResult{Status: status, Reason: "artifact_health", Message: artifactHealthMessage(source, offer, status)}
	}
	if status := evidenceValidationStatus(source.Evidence, now); status != ValidationStatusValid {
		return ValidationResult{Status: status, Reason: "source_evidence", Message: sourceEvidenceMessage(source, status)}
	}
	if status := evidenceValidationStatus(offer.Evidence, now); status != ValidationStatusValid {
		return ValidationResult{Status: status, Reason: "artifact_evidence", Message: artifactEvidenceMessage(source, offer, status)}
	}
	return ValidationResult{Status: ValidationStatusValid}
}

func healthValidationStatus(health Health, now time.Time) ValidationStatus {
	switch health.Status {
	case "", HealthStatusHealthy:
	case HealthStatusDegraded:
		return ValidationStatusDegraded
	case HealthStatusMissingEvidence:
		return ValidationStatusMissingEvidence
	case HealthStatusUnavailable:
		return ValidationStatusUnavailable
	default:
		return ValidationStatusInvalid
	}
	if health.ExpiresAt != nil && !health.ExpiresAt.UTC().After(now) {
		return ValidationStatusStale
	}
	return ValidationStatusValid
}

func evidenceValidationStatus(evidence []Evidence, now time.Time) ValidationStatus {
	if len(evidence) == 0 {
		return ValidationStatusMissingEvidence
	}
	for _, item := range evidence {
		switch item.Status {
		case EvidenceStatusFresh:
		case EvidenceStatusStale:
			return ValidationStatusStale
		case EvidenceStatusMissing:
			return ValidationStatusMissingEvidence
		case EvidenceStatusDegraded, EvidenceStatusUnknownLimit:
			return ValidationStatusDegraded
		case EvidenceStatusUnavailable:
			return ValidationStatusUnavailable
		default:
			return ValidationStatusInvalid
		}
		if item.ExpiresAt != nil && !item.ExpiresAt.UTC().After(now) {
			return ValidationStatusStale
		}
	}
	return ValidationStatusValid
}

func sourceHealthMessage(source ProviderSource, status ValidationStatus) string {
	return fmt.Sprintf("catalog source %q health is %s", source.ID, status)
}

func artifactHealthMessage(source ProviderSource, offer ArtifactOffer, status ValidationStatus) string {
	return fmt.Sprintf("catalog source %q offer %q health is %s", source.ID, offer.ID, status)
}

func sourceEvidenceMessage(source ProviderSource, status ValidationStatus) string {
	return fmt.Sprintf("catalog source %q evidence is %s", source.ID, status)
}

func artifactEvidenceMessage(source ProviderSource, offer ArtifactOffer, status ValidationStatus) string {
	return fmt.Sprintf("catalog source %q offer %q evidence is %s", source.ID, offer.ID, status)
}

func SnapshotDigest(snapshot CatalogSnapshot) string {
	clone := CloneSnapshot(snapshot)
	clone.Integrity = SnapshotIntegrity{}
	body, err := json.Marshal(clone)
	if err != nil {
		return ""
	}
	sum := sha256.Sum256(body)
	return hex.EncodeToString(sum[:])
}

func AttachIntegrity(snapshot CatalogSnapshot, signer string) CatalogSnapshot {
	clone := CloneSnapshot(snapshot)
	digest := SnapshotDigest(clone)
	clone.Integrity = SnapshotIntegrity{
		Mode:      IntegrityModeSignedSnapshotV1,
		Digest:    digest,
		Signature: "signed:" + strings.TrimSpace(signer) + ":" + digest[:16],
	}
	return clone
}
