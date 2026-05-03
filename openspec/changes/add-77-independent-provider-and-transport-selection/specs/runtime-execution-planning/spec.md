## ADDED Requirements
### Requirement: Runtime planning combines provider and transport selections explicitly

The system SHALL combine operator-selected provider source or resolved artifact
state with operator-selected VPN transport profile state only through typed
runtime execution-plan compatibility metadata.

#### Scenario: Compatible provider and transport profile enable a plan

- **GIVEN** an operator has selected one provider source or resolved provider
  artifact
- **AND** the operator has selected one VPN transport profile
- **AND** the host advertises a runtime execution plan whose access method,
  carrier family, engine family, host adapter, and required profile kind match
  those selections
- **WHEN** the shell evaluates startup readiness
- **THEN** the plan is reported as startable or setup-complete for that exact
  combination
- **AND** the readiness metadata names both the provider/artifact side and the
  selected transport profile reference

#### Scenario: Unsupported provider and transport combination fails closed

- **GIVEN** an operator selects a provider source or artifact and a VPN
  transport profile
- **WHEN** no documented runtime execution plan supports that source, carrier,
  engine, host adapter, and profile-kind combination
- **THEN** the host reports the combination as unsupported, unavailable,
  setup-needed, degraded, or missing evidence
- **AND** startup does not silently substitute another provider source, carrier
  family, engine family, host adapter, or transport profile

### Requirement: Runtime planning keeps source and transport defaults scoped

The system SHALL keep provider-source defaults and VPN transport-profile
defaults separately scoped and visible when both axes are combined for startup.

#### Scenario: Saved product intent references both axes

- **GIVEN** a saved product profile or shell preference stores operator intent
  for a provider source and a VPN transport profile
- **WHEN** the shell evaluates that intent for startup
- **THEN** it resolves the provider/source side and the transport-profile side
  independently
- **AND** it validates the resulting combination through runtime execution
  planning before enabling startup
- **AND** stale or unsupported intent on either axis is reported without
  mutating the other axis
