## ADDED Requirements
### Requirement: VPS publishes a versioned provider catalog snapshot

The system SHALL provide a VPS-hosted provider catalog service that publishes
versioned provider/source snapshots for local hosts to sync.

#### Scenario: Local host syncs the VPS catalog

- **GIVEN** the project VPS hosts the supported provider catalog service
- **WHEN** a compatible local host syncs the catalog
- **THEN** the service returns a versioned snapshot with provider source
  identifiers, display metadata, artifact families, access methods,
  compatibility hints, health status, evidence freshness, issuer identity, and
  snapshot freshness metadata
- **AND** the snapshot identifies its intended audience or deployment endpoint
  and a monotonically comparable generation, revision, or epoch value for that
  issuer
- **AND** the snapshot does not include local VPN transport profile material or
  local native-adapter readiness
- **AND** the local host can reject stale, invalid, unsigned, wrong-audience,
  rollback, or unsupported snapshots before treating their entries as startable
  inputs

### Requirement: VPS artifact issuance is explicit and redacted by default

The system SHALL issue or export remote provider artifacts only through
explicit service actions with TTL, provenance, authorization, and redaction
rules.

#### Scenario: Operator or local host requests a short-lived artifact

- **GIVEN** a catalog source can issue a supported remote artifact such as a
  managed TURN handoff, future SFU attach material, camera-stream access, or a
  proxy-account delivery reference
- **WHEN** an authorized caller requests artifact issuance or export
- **THEN** the service returns a typed artifact reference or explicit
  secret-bearing export according to the documented action
- **AND** the response includes expiry, provenance, source identity, and
  artifact family metadata
- **AND** mutating issue, export, regeneration, or account-backed delivery
  actions require a documented operation identity or idempotency key so retries
  cannot duplicate accounts, rotate delivery material twice, or produce two
  unrelated artifacts for one caller action
- **AND** ordinary catalog reads and artifact status reads remain redacted
- **AND** the service records enough audit context to explain who requested the
  action and what result occurred

### Requirement: VPS service exposes health and evidence without overclaiming readiness

The system SHALL expose remote source health and evidence fields as inputs to
local compatibility evaluation and diagnostics without claiming client-side
startup readiness.

#### Scenario: Remote source is degraded or missing evidence

- **GIVEN** a catalog source has stale probes, degraded throughput, missing
  remote ingress evidence, failed backend health, or an unknown limit domain
- **WHEN** the VPS service publishes the catalog or artifact status
- **THEN** it marks the source or artifact offer with explicit health,
  freshness, degraded reason, or missing-evidence metadata
- **AND** it does not mark the local provider/transport combination as
  startable on behalf of a specific client host
- **AND** the local control plane can report the degraded or missing-evidence
  status through provider/transport compatibility instead of silently ignoring
  it

### Requirement: VPS catalog writes stay behind an authenticated admin boundary

The system SHALL keep catalog mutations, source enablement, health-probe
configuration, and delivery-material regeneration behind an authenticated and
audited VPS boundary.

#### Scenario: Unauthorized caller attempts to mutate the catalog

- **GIVEN** the provider catalog service is reachable through the supported VPS
  deployment
- **WHEN** an unauthenticated or unauthorized caller attempts to enable a
  source, change artifact policy, regenerate delivery material, or edit health
  probes
- **THEN** the service rejects the request explicitly
- **AND** it does not expose arbitrary shell execution, raw config editing, or
  unrelated host-service management
- **AND** failed and successful mutation attempts are auditable without logging
  raw provider secrets

### Requirement: VPS catalog authorization scopes are separated

The system SHALL separate read-only catalog sync, artifact issue/export, and
admin mutation authority with explicit deny-by-default authorization checks.

#### Scenario: Read-only client credential attempts a privileged action

- **GIVEN** a caller is authorized only to sync catalog snapshots
- **WHEN** it attempts artifact issue/export, source enablement, policy change,
  delivery-material regeneration, or health-probe configuration
- **THEN** the service rejects the request before performing the action
- **AND** the rejection identifies an authorization failure without revealing
  whether hidden sources, accounts, or delivery material exist
- **AND** the service records bounded audit context without raw provider secrets

### Requirement: Cached remote catalog data fails closed when freshness is lost

The system SHALL allow local hosts to inspect cached remote catalog data while
preventing stale or unverifiable data from becoming new startable runtime input.

#### Scenario: Client is offline with an expired cached snapshot

- **GIVEN** a local host has a previously synced VPS provider catalog snapshot
- **AND** the snapshot is now expired, invalid, unsupported by schema,
  wrong-audience, older than the highest trusted generation for that issuer, or
  no longer verifiable
- **WHEN** the shell reads provider sources or requests startup from that
  snapshot
- **THEN** the host may show the cached source for diagnostics or recovery
- **BUT** it reports the source or artifact as stale, unavailable, or
  missing-evidence for startup
- **AND** it does not mint a new remote artifact or fall back to another source
  without explicit operator action
