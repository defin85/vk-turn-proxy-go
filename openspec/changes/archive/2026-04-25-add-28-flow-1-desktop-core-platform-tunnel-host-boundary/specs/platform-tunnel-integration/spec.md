## ADDED Requirements
### Requirement: Desktop platform-tunnel startup may cross a packaged host boundary without splitting the contract

The system SHALL allow documented desktop system-tunnel startup to cross a
packaged host boundary between the Go control plane and an OS-specific native
desktop adapter while keeping one typed platform-tunnel contract.

#### Scenario: Native desktop adapter succeeds but runtime attach still decides readiness

- **GIVEN** a packaged desktop host whose native adapter can acquire the OS
  tunnel primitive for one documented desktop mode
- **WHEN** the Go control plane has not yet attached the documented runtime
  successfully
- **THEN** the repository does not claim `ready=true`
- **AND** readiness remains governed by the typed startup result from the
  packaged host boundary as a whole

### Requirement: Cross-boundary desktop semantics stay reusable across native adapters

The system SHALL keep the cross-boundary desktop platform-tunnel contract
expressed in typed startup semantics that later desktop adapters can reuse
without inheriting one OS adapter's API names.

#### Scenario: Later packaged desktop host uses a different native system-tunnel primitive

- **GIVEN** a later packaged desktop host that uses a different native
  system-tunnel primitive from the first shipped desktop mode
- **WHEN** that host reuses the same platform-tunnel contract shape
- **THEN** readiness still depends on native bring-up plus runtime attach
- **AND** the shared contract does not require one OS adapter's API objects to
  appear outside the native adapter boundary
