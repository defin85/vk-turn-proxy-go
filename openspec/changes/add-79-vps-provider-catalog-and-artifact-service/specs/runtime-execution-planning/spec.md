## ADDED Requirements
### Requirement: Runtime planning treats VPS catalog hints as inputs, not decisions

Runtime execution planning SHALL consume VPS catalog artifact families,
access-method hints, remote ingress facts, and evidence state as inputs while
keeping final provider/transport compatibility decisions local.

#### Scenario: VPS source advertises a compatible access method but local profile is missing

- **GIVEN** a fresh VPS catalog source advertises a `generic_turn` artifact
  offer with a supported access method such as `turn_credentials`
- **AND** the current host has no selected VPN transport profile matching the
  required profile kind for the candidate runtime plan
- **WHEN** compatibility or startup readiness is evaluated
- **THEN** runtime planning reports the candidate as setup-needed or blocked by
  the transport-profile axis
- **AND** the remote source is not treated as startable merely because the VPS
  catalog advertises compatible access-method hints

#### Scenario: VPS source lacks required evidence for a plan

- **GIVEN** a VPS catalog source advertises an artifact offer and remote ingress
  facts
- **AND** the offer lacks required health, freshness, limit-domain, or
  data-plane evidence for the selected runtime plan
- **WHEN** compatibility is evaluated
- **THEN** runtime planning reports a degraded or missing-evidence status for
  that exact candidate
- **AND** startup does not silently substitute a different remote source,
  carrier family, engine family, host adapter, or VPN transport profile
