## ADDED Requirements
### Requirement: VPS provider catalog service emits bounded operational signals

The system SHALL emit structured events and low-cardinality metrics for VPS
provider catalog sync, artifact issuance, evidence freshness, degraded state,
and authorization outcomes.

#### Scenario: Artifact issuance fails because source evidence is stale

- **GIVEN** the VPS provider catalog service receives an artifact issue request
  for a source whose evidence is stale or degraded
- **WHEN** the request is rejected or marked non-startable
- **THEN** the service emits a structured event with source family, artifact
  family, action, status, failing axis or reason, and request outcome
- **AND** metrics use bounded labels such as action, source family, artifact
  family, and status
- **AND** raw provider secrets, account links, tokens, cookies, QR payloads, or
  client-specific identifiers are not emitted as log fields or metric labels

### Requirement: Local hosts report remote catalog freshness in diagnostics

The system SHALL include remote catalog freshness and validation status in
diagnostics without exposing secret-bearing remote artifact material.

#### Scenario: Support bundle includes a stale remote catalog

- **GIVEN** a local host has synced or cached a VPS provider catalog snapshot
- **WHEN** diagnostics are exported
- **THEN** the diagnostics include catalog endpoint identity, schema version,
  generation, freshness status, validation result, source health summaries, and
  artifact-family counts
- **AND** they do not include raw issued artifacts, raw provider credentials,
  account delivery links, or local VPN transport profile secrets
