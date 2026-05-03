## ADDED Requirements
### Requirement: VK multi-allocation active-standby behavior is anchored by explicit evidence

The system SHALL keep explicit compatibility or release evidence for the
supported VK `active_standby` multi-allocation slice so future runtime changes
do not rely on chat-level assumptions.

#### Scenario: Standby promotion is backed by explicit evidence

- **GIVEN** the repository claims support for VK `active_standby`
  multi-allocation runtime
- **WHEN** compatibility or release verification is reviewed
- **THEN** the evidence set includes one scenario where a ready standby
  allocation is promoted after active-allocation failure
- **AND** regressions in that promotion path fail verification with explicit
  scenario names

#### Scenario: Allocation quota or partial bring-up failure is backed by explicit evidence

- **GIVEN** the repository claims support for VK `active_standby`
  multi-allocation runtime
- **WHEN** compatibility or release verification is reviewed
- **THEN** the evidence set includes one scenario where the requested standby
  allocation count cannot be established
- **AND** the repository records explicit failure behavior instead of silent
  degradation to a smaller allocation set

### Requirement: VK throughput-scaling claims require current live evidence

The system SHALL block VK multi-allocation throughput-scaling claims unless the
current compatibility evidence proves that the selected VK contour scales with
additional connections, allocations, identities, or calls.

#### Scenario: Current VK contour does not scale with connection count

- **GIVEN** compatibility evidence for the selected VK TURN contour includes
  one-connection and multi-connection measurements
- **WHEN** the multi-connection measurement does not materially exceed the
  one-connection throughput ceiling
- **THEN** VK compatibility marks throughput scaling as unsupported or
  degraded for that contour
- **AND** release or operator wording keeps VK multi-allocation scoped to
  resilience
- **AND** any future bandwidth claim requires new live evidence for an
  independent limit domain
