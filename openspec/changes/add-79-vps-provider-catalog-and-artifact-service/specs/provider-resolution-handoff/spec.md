## ADDED Requirements
### Requirement: Resolution handoff accepts explicitly issued VPS artifacts

The provider-resolution handoff layer SHALL model explicitly issued VPS
artifacts as provider-resolution records with remote provenance and expiry.

#### Scenario: Remote artifact enters the local handoff model

- **GIVEN** a VPS provider catalog source supports an explicit artifact issue
  action
- **WHEN** the local host requests the action and receives an issued artifact
- **THEN** the local handoff record identifies the remote catalog endpoint,
  source reference, snapshot generation, artifact reference, artifact family,
  access methods, expiry, and provenance
- **AND** the handoff state can become `expired`, `failed`, or stale when the
  remote artifact or source freshness is no longer valid
- **AND** no runtime session starts merely because the remote artifact was
  issued

### Requirement: Remote artifact export remains explicit

The provider-resolution handoff layer SHALL require explicit export actions
before exposing secret-bearing remote artifact material.

#### Scenario: Caller requests a VPS-issued secret handoff

- **GIVEN** a remote handoff record supports a documented export action
- **WHEN** an authorized caller requests that export
- **THEN** the host returns the export only within the artifact TTL and
  according to the remote service redaction policy
- **AND** ordinary resolution reads before or after the export do not retain
  raw secret material
- **AND** export failure does not synthesize a guessed generic-turn link,
  proxy link, room token, or config payload
