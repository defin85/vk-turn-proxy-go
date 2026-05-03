## ADDED Requirements
### Requirement: Client control plane syncs remote VPS provider catalogs

The client control plane SHALL expose remote VPS provider catalog snapshots as
provider/source facts only after validating snapshot schema, freshness, issuer,
audience, generation, anti-rollback, and redaction rules.

#### Scenario: Shell reads sources from a valid VPS catalog snapshot

- **GIVEN** the local host is configured with a supported VPS provider catalog
  endpoint
- **AND** the endpoint returns a valid, fresh, and compatible snapshot
- **WHEN** the shell requests provider/source catalog data through the local
  control plane
- **THEN** the response includes the remote provider/source entries with stable
  source references, artifact families, access methods, health status, and
  evidence metadata
- **AND** the response identifies those entries as remote VPS-backed sources
- **AND** the host records the accepted issuer, audience, endpoint identity, and
  generation for later rollback detection
- **AND** it does not store or return local VPN transport profile material as
  part of the provider source entry

### Requirement: Client control plane fails closed for stale remote catalog data

The client control plane SHALL keep stale, invalid, unsigned, unsupported, or
missing-evidence remote catalog data out of startable runtime requests.

#### Scenario: Cached remote source is no longer fresh

- **GIVEN** the local host has a cached VPS catalog snapshot
- **AND** the snapshot is expired, invalid, unverifiable, wrong-audience,
  rolled back below the highest accepted generation, unsupported by schema, or
  missing required evidence
- **WHEN** the shell reads provider sources or evaluates compatibility
- **THEN** the host reports the affected source or artifact as stale,
  unavailable, unsupported, degraded, or missing evidence
- **AND** startup requests that depend on that source fail before provider,
  carrier, engine, or native-adapter startup
- **AND** the host does not substitute another remote source or the most recent
  compatible VPN transport profile

### Requirement: Client control plane maps VPS artifacts into typed resolution handoffs

The client control plane SHALL represent explicitly issued VPS artifacts as
typed provider-resolution records with remote provenance and expiry.

#### Scenario: VPS artifact is issued for local compatibility evaluation

- **GIVEN** a valid VPS catalog source supports an explicit artifact issue
  action
- **WHEN** the local host requests that action and receives a remote artifact
  reference or handoff
- **THEN** the host records a provider-resolution handoff with the remote
  source reference, snapshot generation, artifact family, access methods,
  expiry, and provenance
- **AND** ordinary shell reads remain redacted unless the caller requested a
  documented secret-bearing export action
- **AND** compatibility evaluation consumes the typed remote artifact facts
  rather than parsing display labels or raw provider payloads
