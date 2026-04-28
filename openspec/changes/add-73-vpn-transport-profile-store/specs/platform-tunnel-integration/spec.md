## ADDED Requirements

### Requirement: Platform tunnel readiness includes transport profile prerequisites

The system SHALL treat required VPN transport profile validation as a platform
tunnel prerequisite, alongside native adapter bring-up, route policy, and
runtime attach.

#### Scenario: Native adapter exists but profile material is missing

- **GIVEN** a packaged host can bring up a native tunnel adapter such as
  `android_vpn_service` or `windows_wintun`
- **AND** the requested execution plan requires a transport profile that is not
  configured or compatible
- **WHEN** startup validates platform tunnel prerequisites
- **THEN** startup fails before `ready=true`
- **AND** the failure identifies the missing or incompatible transport profile
- **AND** the failure uses the typed `transport_profile` prerequisite rather
  than a generic host implementation prerequisite
- **AND** the host does not claim readiness from native adapter availability
  alone

#### Scenario: Transport profile is validated before runtime attach

- **GIVEN** a selected platform tunnel mode, execution plan, and transport
  profile reference
- **WHEN** the host starts that mode
- **THEN** it validates the profile against the plan before reporting readiness
- **AND** readiness remains gated on native bring-up plus successful runtime
  attach after profile validation

#### Scenario: Profile validation failure does not trigger native cleanup

- **GIVEN** a platform tunnel startup request fails during transport profile
  validation
- **WHEN** the host returns the startup failure
- **THEN** the host has not yet created native tunnel resources that require
  route or adapter cleanup
- **AND** cleanup remains required only for failures after native bring-up or
  route mutation begins
