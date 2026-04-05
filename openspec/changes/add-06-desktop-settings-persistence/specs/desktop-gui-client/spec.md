## ADDED Requirements
### Requirement: Desktop GUI shell persists local profile settings

The system SHALL persist desktop-shell profile settings locally so operators do not need to recreate them after every GUI or local-host restart.

#### Scenario: Restarting the desktop shell restores saved profiles

- **GIVEN** a desktop operator has saved one or more profiles in the GUI shell
- **WHEN** the GUI shell restarts and reconnects to a compatible local host
- **THEN** it restores those saved profiles into the GUI state
- **AND** it rehydrates them back into the local host without requiring the operator to re-enter them manually

#### Scenario: Restarting the desktop shell restores the selected profile and draft

- **GIVEN** the desktop operator has a selected profile or an in-progress draft in the GUI shell
- **WHEN** the GUI shell restarts
- **THEN** it restores the selected profile and draft values from local persistence
- **AND** it does not require the operator to rebuild the form state from scratch
