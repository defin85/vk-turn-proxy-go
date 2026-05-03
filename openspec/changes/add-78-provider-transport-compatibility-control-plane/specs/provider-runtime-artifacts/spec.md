## ADDED Requirements
### Requirement: Provider artifacts expose compatibility-safe references

The provider-runtime artifact layer SHALL expose stable, redacted references
that the compatibility evaluator can use without leaking provider secrets.

#### Scenario: Resolved artifact participates in compatibility evaluation

- **GIVEN** a provider resolution yields a resolved artifact with one or more
  artifact families or access methods
- **WHEN** the provider/transport compatibility evaluator reads that artifact
- **THEN** it can use a stable resolution or artifact reference, artifact
  family, access-method metadata, expiry state, and supported action metadata
- **AND** it does not require raw TURN credentials, room tokens, cookies, camera
  tokens, or other provider secrets in the compatibility response

#### Scenario: Expired artifact blocks candidate

- **GIVEN** a previously compatible provider artifact expires or is cancelled
- **WHEN** compatibility candidates are evaluated
- **THEN** candidates that depend on that artifact become stale or unavailable
- **AND** the failing axis identifies the provider artifact or access method
- **AND** the host does not reuse raw secret material from an older ordinary
  read to keep the candidate startable
