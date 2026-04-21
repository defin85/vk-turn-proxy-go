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
