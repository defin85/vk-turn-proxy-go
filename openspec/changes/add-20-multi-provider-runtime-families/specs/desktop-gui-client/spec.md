## ADDED Requirements
### Requirement: Desktop GUI shell renders provider entry from host descriptors

The system SHALL let the desktop GUI build provider entry flows from
host-reported descriptors rather than from hard-coded provider-name-specific
assumptions.

#### Scenario: Operator starts a provider flow from a descriptor-driven form

- **GIVEN** a desktop GUI connected to a compatible host
- **WHEN** the operator opens the provider entry surface
- **THEN** the GUI renders provider-specific input and continuation guidance
  from the host-reported descriptor metadata
- **AND** it does not require desktop-specific VK-only assumptions to discover
  the correct workflow

#### Scenario: Desktop GUI respects external-browser-required providers

- **GIVEN** a provider descriptor that reports an external-browser requirement
  for auth or continuation
- **WHEN** the operator starts that provider flow from desktop
- **THEN** the GUI uses the supported external-browser path
- **AND** it does not silently substitute an embedded browser surface

### Requirement: Desktop GUI shell presents post-resolution actions from artifact capabilities

The system SHALL let the desktop GUI present post-resolution actions according
to the resolved artifact family and host-reported capabilities.

#### Scenario: Desktop GUI shows only supported actions for a resolved artifact

- **GIVEN** a resolved provider artifact exposed through the local host
- **WHEN** the desktop GUI renders the resolved state
- **THEN** it shows only the actions that the host reported as supported for
  that artifact family
- **AND** actions such as same-device start, export, room open, or camera open
  are not inferred from the provider name alone

### Requirement: Desktop GUI shell keeps unsupported families honest

The system SHALL keep unsupported or partially supported artifact families
fail-closed in desktop UX.

#### Scenario: Resolved artifact lacks local desktop execution support

- **GIVEN** a resolved provider artifact whose family is discoverable but not
  executable by the current desktop host build
- **WHEN** the GUI renders the resolved state
- **THEN** it reports that the artifact is not supported for local desktop
  execution
- **AND** it does not present the artifact as a ready local runtime session
