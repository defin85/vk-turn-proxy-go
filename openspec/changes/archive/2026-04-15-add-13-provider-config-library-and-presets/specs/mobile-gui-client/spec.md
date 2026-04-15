## ADDED Requirements
### Requirement: Mobile GUI manages provider configs through workflow-first surfaces

The system SHALL let the mobile GUI add, edit, delete, and apply reusable
provider configs without collapsing them back into one long profile form.

#### Scenario: Mobile operator edits a provider config

- **GIVEN** a mobile GUI connected to a compatible host
- **AND** the chosen provider advertises a supported settings schema
- **WHEN** the operator opens the mobile provider-config surface
- **THEN** the app renders the same descriptor-driven provider fields used by
  desktop
- **AND** it keeps provider-config CRUD separate from runtime defaults and
  profile runtime actions

#### Scenario: Mobile blocks an incompatible provider config

- **GIVEN** a stored provider config whose provider descriptor is unavailable or
  unsupported on the connected host
- **WHEN** the operator views that config on mobile
- **THEN** the app marks it as unavailable
- **AND** it does not silently apply that config into a new draft

### Requirement: Mobile GUI offers curated preset bootstrap flows

The system SHALL provide mobile-first preset bootstrap entry points for the
primary provider families while gating those presets on host capability.

#### Scenario: Mobile starts a new draft from an available preset

- **GIVEN** the connected mobile host advertises the provider targeted by a
  preset card
- **WHEN** the operator chooses the `VK`, `WB Stream`, or `RTK Smarthome`
  preset on mobile
- **THEN** the app seeds a new workflow draft with that provider family and
  curated defaults
- **AND** the operator can continue into provider-config apply/create flows
  without re-entering the provider taxonomy manually

#### Scenario: Mobile keeps unavailable presets explicit

- **GIVEN** a preset whose target provider is not advertised by the connected
  host
- **WHEN** the operator views the mobile preset catalog
- **THEN** the app keeps that preset visible but disabled
- **AND** it explains that the current host build does not advertise the
  required provider
