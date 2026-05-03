package vpscatalog

import "time"

const (
	SchemaVersion = "1"

	IntegrityModeSignedSnapshotV1 = "signed_snapshot_v1"
)

type AuthScope string

const (
	AuthScopeCatalogRead   AuthScope = "catalog_read"
	AuthScopeArtifactIssue AuthScope = "artifact_issue_export"
	AuthScopeAdminMutation AuthScope = "admin_mutation"
)

type HealthStatus string

const (
	HealthStatusHealthy         HealthStatus = "healthy"
	HealthStatusDegraded        HealthStatus = "degraded"
	HealthStatusUnavailable     HealthStatus = "unavailable"
	HealthStatusMissingEvidence HealthStatus = "missing_evidence"
)

type EvidenceStatus string

const (
	EvidenceStatusFresh        EvidenceStatus = "fresh"
	EvidenceStatusStale        EvidenceStatus = "stale"
	EvidenceStatusMissing      EvidenceStatus = "missing"
	EvidenceStatusDegraded     EvidenceStatus = "degraded"
	EvidenceStatusUnavailable  EvidenceStatus = "unavailable"
	EvidenceStatusUnknownLimit EvidenceStatus = "unknown_limit"
)

type ValidationStatus string

const (
	ValidationStatusValid           ValidationStatus = "valid"
	ValidationStatusInvalid         ValidationStatus = "invalid"
	ValidationStatusStale           ValidationStatus = "stale"
	ValidationStatusUnsigned        ValidationStatus = "unsigned"
	ValidationStatusWrongAudience   ValidationStatus = "wrong_audience"
	ValidationStatusWrongIssuer     ValidationStatus = "wrong_issuer"
	ValidationStatusWrongEndpoint   ValidationStatus = "wrong_endpoint"
	ValidationStatusRollback        ValidationStatus = "rollback"
	ValidationStatusUnsupported     ValidationStatus = "unsupported"
	ValidationStatusMissingEvidence ValidationStatus = "missing_evidence"
	ValidationStatusDegraded        ValidationStatus = "degraded"
	ValidationStatusUnavailable     ValidationStatus = "unavailable"
)

type RedactionMode string

const (
	RedactionModeReferenceOnly RedactionMode = "reference_only"
	RedactionModeSummaryOnly   RedactionMode = "summary_only"
	RedactionModeSecretExport  RedactionMode = "secret_export"
)

type RedactionPolicy struct {
	OrdinaryReads  RedactionMode `json:"ordinary_reads,omitempty"`
	Events         RedactionMode `json:"events,omitempty"`
	Diagnostics    RedactionMode `json:"diagnostics,omitempty"`
	PersistedState RedactionMode `json:"persisted_state,omitempty"`
	Export         RedactionMode `json:"export,omitempty"`
}

func DefaultRedactionPolicy() RedactionPolicy {
	return RedactionPolicy{
		OrdinaryReads:  RedactionModeReferenceOnly,
		Events:         RedactionModeSummaryOnly,
		Diagnostics:    RedactionModeSummaryOnly,
		PersistedState: RedactionModeReferenceOnly,
		Export:         RedactionModeSecretExport,
	}
}

type SnapshotIntegrity struct {
	Mode      string `json:"mode,omitempty"`
	Digest    string `json:"digest,omitempty"`
	Signature string `json:"signature,omitempty"`
}

type CatalogSnapshot struct {
	Version     string            `json:"version"`
	GeneratedAt time.Time         `json:"generated_at"`
	ExpiresAt   time.Time         `json:"expires_at"`
	Issuer      string            `json:"issuer"`
	Audience    string            `json:"audience"`
	EndpointID  string            `json:"endpoint_id"`
	Generation  uint64            `json:"generation"`
	Integrity   SnapshotIntegrity `json:"integrity,omitempty"`
	Sources     []ProviderSource  `json:"sources,omitempty"`
}

type ProviderSource struct {
	ID             string            `json:"id"`
	ProviderID     string            `json:"provider_id"`
	DisplayName    string            `json:"display_name"`
	Description    string            `json:"description,omitempty"`
	SourceFamily   string            `json:"source_family,omitempty"`
	Health         Health            `json:"health,omitempty"`
	Evidence       []Evidence        `json:"evidence,omitempty"`
	ArtifactOffers []ArtifactOffer   `json:"artifact_offers,omitempty"`
	Metadata       map[string]string `json:"metadata,omitempty"`
}

type ArtifactOffer struct {
	ID                     string             `json:"id"`
	Family                 string             `json:"family"`
	AccessMethods          []string           `json:"access_methods,omitempty"`
	Actions                []string           `json:"actions,omitempty"`
	RemoteEndpointFamily   string             `json:"remote_endpoint_family,omitempty"`
	RemoteEndpointRole     string             `json:"remote_endpoint_role,omitempty"`
	CompatibleProfileKinds []string           `json:"compatible_profile_kinds,omitempty"`
	MaxTTLSeconds          int                `json:"max_ttl_seconds,omitempty"`
	Health                 Health             `json:"health,omitempty"`
	Evidence               []Evidence         `json:"evidence,omitempty"`
	Redaction              RedactionPolicy    `json:"redaction,omitempty"`
	Provenance             ArtifactProvenance `json:"provenance,omitempty"`
	Metadata               map[string]string  `json:"metadata,omitempty"`
}

type Health struct {
	Status         HealthStatus `json:"status,omitempty"`
	CheckedAt      *time.Time   `json:"checked_at,omitempty"`
	ExpiresAt      *time.Time   `json:"expires_at,omitempty"`
	DegradedReason string       `json:"degraded_reason,omitempty"`
	Message        string       `json:"message,omitempty"`
	LimitDomain    string       `json:"limit_domain,omitempty"`
}

type Evidence struct {
	Kind        string         `json:"kind"`
	Subject     string         `json:"subject,omitempty"`
	Status      EvidenceStatus `json:"status"`
	ObservedAt  *time.Time     `json:"observed_at,omitempty"`
	ExpiresAt   *time.Time     `json:"expires_at,omitempty"`
	Message     string         `json:"message,omitempty"`
	LimitDomain string         `json:"limit_domain,omitempty"`
}

type ArtifactProvenance struct {
	EndpointID string `json:"endpoint_id,omitempty"`
	Issuer     string `json:"issuer,omitempty"`
	Audience   string `json:"audience,omitempty"`
	Generation uint64 `json:"generation,omitempty"`
	SourceID   string `json:"source_id,omitempty"`
	OfferID    string `json:"offer_id,omitempty"`
}

type AuditContext struct {
	Actor     string            `json:"actor,omitempty"`
	RequestID string            `json:"request_id,omitempty"`
	Reason    string            `json:"reason,omitempty"`
	Metadata  map[string]string `json:"metadata,omitempty"`
}

type ArtifactIssueRequest struct {
	SourceID     string       `json:"source_id"`
	OfferID      string       `json:"offer_id"`
	OperationID  string       `json:"operation_id"`
	TTLSeconds   int          `json:"ttl_seconds,omitempty"`
	ExportSecret bool         `json:"export_secret,omitempty"`
	Audit        AuditContext `json:"audit,omitempty"`
}

type ArtifactIssueResponse struct {
	OperationID string             `json:"operation_id"`
	IssuedAt    time.Time          `json:"issued_at"`
	ExpiresAt   time.Time          `json:"expires_at"`
	Source      SourceReference    `json:"source"`
	Artifact    ArtifactReference  `json:"artifact"`
	Export      *ArtifactExport    `json:"export,omitempty"`
	Redaction   RedactionPolicy    `json:"redaction,omitempty"`
	Provenance  ArtifactProvenance `json:"provenance,omitempty"`
}

type SourceReference struct {
	EndpointID string `json:"endpoint_id"`
	Issuer     string `json:"issuer"`
	Audience   string `json:"audience,omitempty"`
	Generation uint64 `json:"generation"`
	ProviderID string `json:"provider_id"`
	SourceID   string `json:"source_id"`
}

type ArtifactReference struct {
	ID                     string     `json:"id"`
	SourceID               string     `json:"source_id"`
	OfferID                string     `json:"offer_id"`
	Family                 string     `json:"family"`
	AccessMethods          []string   `json:"access_methods,omitempty"`
	Actions                []string   `json:"actions,omitempty"`
	RemoteEndpointFamily   string     `json:"remote_endpoint_family,omitempty"`
	RemoteEndpointRole     string     `json:"remote_endpoint_role,omitempty"`
	CompatibleProfileKinds []string   `json:"compatible_profile_kinds,omitempty"`
	Health                 Health     `json:"health,omitempty"`
	Evidence               []Evidence `json:"evidence,omitempty"`
	ExpiresAt              time.Time  `json:"expires_at"`
}

type ArtifactExport struct {
	Kind            string `json:"kind,omitempty"`
	Payload         string `json:"payload,omitempty"`
	PayloadRedacted bool   `json:"payload_redacted,omitempty"`
}

type AuditRecord struct {
	Timestamp      time.Time `json:"timestamp"`
	Action         string    `json:"action"`
	Scope          AuthScope `json:"scope,omitempty"`
	Status         string    `json:"status"`
	SourceFamily   string    `json:"source_family,omitempty"`
	ArtifactFamily string    `json:"artifact_family,omitempty"`
	SourceID       string    `json:"source_id,omitempty"`
	OfferID        string    `json:"offer_id,omitempty"`
	OperationID    string    `json:"operation_id,omitempty"`
	Reason         string    `json:"reason,omitempty"`
	Actor          string    `json:"actor,omitempty"`
}

type MetricsSnapshot struct {
	CatalogReads     map[string]uint64 `json:"catalog_reads,omitempty"`
	ArtifactIssues   map[string]uint64 `json:"artifact_issues,omitempty"`
	Authorization    map[string]uint64 `json:"authorization,omitempty"`
	EvidenceOutcomes map[string]uint64 `json:"evidence_outcomes,omitempty"`
}
