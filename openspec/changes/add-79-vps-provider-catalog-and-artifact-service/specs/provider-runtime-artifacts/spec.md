## ADDED Requirements
### Requirement: Provider artifacts support VPS-backed source and artifact references

The provider-runtime artifact layer SHALL represent VPS-backed provider sources
and artifacts as typed references with provenance, freshness, artifact family,
and access-method metadata.

#### Scenario: Remote catalog entry becomes a provider source descriptor

- **GIVEN** a valid VPS provider catalog snapshot includes a provider/source
  entry and one or more artifact offers
- **WHEN** the local host exposes that entry through provider-runtime artifacts
  or provider/source catalog reads
- **THEN** it preserves the remote source reference, snapshot generation,
  artifact family, access methods, health status, evidence freshness, and
  provenance
- **AND** it does not flatten the entry into a static provider link or local VPN
  transport profile
- **AND** it does not require shell code to branch on the remote source display
  name to discover artifact behavior

### Requirement: Remote artifact ordinary reads remain redacted

The provider-runtime artifact layer SHALL keep VPS-issued artifacts redacted in
ordinary reads and diagnostics unless an explicit export action authorizes
secret-bearing material.

#### Scenario: Shell inspects a VPS-issued artifact

- **GIVEN** a remote VPS artifact has been explicitly issued and linked to a
  local provider-resolution record
- **WHEN** the shell lists resolutions, reads the artifact, consumes events, or
  exports ordinary diagnostics
- **THEN** the host returns only stable references, artifact family,
  access-method metadata, expiry, health, evidence, and redacted summaries
- **AND** raw TURN credentials, room tokens, proxy links, cookies, camera
  tokens, QR payloads, or config exports are absent unless requested through a
  documented export action
