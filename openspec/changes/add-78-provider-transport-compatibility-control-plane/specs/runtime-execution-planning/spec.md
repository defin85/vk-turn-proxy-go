## ADDED Requirements
### Requirement: Execution planning reports combination compatibility reasons

Runtime execution planning SHALL report why a provider/source and VPN
transport profile combination is startable, setup-needed, unsupported,
degraded, stale, or missing evidence.

#### Scenario: Execution plan is blocked by profile compatibility

- **GIVEN** a provider/source side can produce the access method required by a
  runtime execution plan
- **AND** the selected VPN transport profile kind or validation state does not
  satisfy that plan
- **WHEN** compatibility is evaluated
- **THEN** the plan is reported as non-startable with failing axis
  `transport_profile`
- **AND** the reason identifies the missing, invalid, incompatible, stale, or
  unselected profile state

#### Scenario: Execution plan is blocked by provider artifact state

- **GIVEN** a VPN transport profile is compatible with one runtime execution
  plan
- **AND** the selected provider/source side lacks the required artifact family,
  access method, expiry state, or action support
- **WHEN** compatibility is evaluated
- **THEN** the plan is reported as non-startable with a provider/source or
  artifact/access-method failing axis
- **AND** the host does not allow the compatible transport profile to imply a
  startable provider path

### Requirement: Combination evaluator preserves explicit plan identity

Runtime execution planning SHALL keep the selected access method, carrier
family, engine family, host adapter, and required profile kind explicit in
compatibility candidates and startup validation.

#### Scenario: Multiple plans could consume the same source or profile

- **GIVEN** a source or transport profile could appear in more than one
  runtime execution plan candidate
- **WHEN** the host reports candidates or validates startup
- **THEN** each candidate names its exact plan identity
- **AND** startup validates the requested identity rather than choosing another
  compatible-looking plan implicitly
