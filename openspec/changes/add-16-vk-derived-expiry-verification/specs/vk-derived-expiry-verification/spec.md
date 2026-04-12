## ADDED Requirements
### Requirement: Repository maintains a repo-owned VK derived-expiry verification workflow

The repository SHALL define one repo-owned workflow that verifies VK derived
TURN credential expiry across the candidate boundary without persisting raw live
handoff secrets in committed evidence.

#### Scenario: Pre-expiry verification succeeds

- **GIVEN** a fresh live VK-derived `generic-turn://...` handoff link whose
  username yields a repository-recognized derived expiry
- **WHEN** the operator runs the repo-owned verification workflow before that
  derived expiry
- **THEN** the workflow records the derived expiry boundary
- **AND** a fresh TURN Allocate succeeds before the boundary

#### Scenario: Post-expiry verification fails after the boundary

- **GIVEN** the same live VK-derived handoff link and the previously recorded
  derived expiry boundary
- **WHEN** the operator reruns the repo-owned verification workflow after the
  derived expiry plus a small grace period
- **THEN** a fresh TURN Allocate fails explicitly
- **AND** the recorded result is suitable to confirm the derived expiry
  boundary rather than only the pre-expiry behavior

#### Scenario: Verification evidence stays redacted

- **GIVEN** a live VK-derived handoff link used for expiry verification
- **WHEN** the repository stores operator notes, logs, or artifacts from that
  workflow
- **THEN** the stored evidence does not persist the raw `generic-turn://...`
  secret, raw password, or other reusable credential material
- **AND** the evidence still preserves the observed expiry boundary and the
  success or failure outcome needed for release confidence
