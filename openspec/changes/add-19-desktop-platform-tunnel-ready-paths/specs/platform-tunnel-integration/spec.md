## ADDED Requirements
### Requirement: Desktop platform tunnel support is claimed per packaged target and mode

The system SHALL claim desktop platform tunnel support only for the packaged desktop target and typed mode that actually satisfies the documented prerequisites.
A supported ready path on one desktop OS SHALL NOT silently imply support for another desktop OS or mode.

#### Scenario: Windows readiness does not imply other desktop readiness

- **GIVEN** a production Windows desktop package that is documented as supporting a ready `windows_wintun` path
- **AND** a different desktop target still lacks its own documented ready-path implementation such as `linux_tun` or `apple_network_extension`
- **WHEN** the operator inspects platform tunnel capability on that other desktop target
- **THEN** the host reports that target mode as unsupported or missing its prerequisite
- **AND** the shell does not claim generic desktop system tunnel support from the Windows evidence alone

#### Scenario: Desktop target reports support only for its satisfied mode

- **GIVEN** a packaged desktop target whose host satisfies the documented prerequisites for one desktop platform tunnel mode
- **WHEN** the client queries host capabilities
- **THEN** the host reports support explicitly for that mode only
- **AND** the report confirms the documented prerequisites are satisfied

### Requirement: Packaged Windows hosts can establish the first desktop ready `windows_wintun` path

The system SHALL support the first concrete desktop platform tunnel ready path for packaged Windows hosts through `windows_wintun`.

#### Scenario: Packaged Windows host reaches ready state

- **GIVEN** a Windows desktop package that includes the documented `windows_wintun` implementation and packaged host
- **AND** the target machine satisfies the documented driver and privilege prerequisites
- **WHEN** the operator starts system tunnel mode for `windows_wintun`
- **THEN** startup returns `ready=true` for `windows_wintun`
- **AND** the host reports readiness only after driver validation, route preparation, host bring-up, and runtime attach succeed

#### Scenario: Wintun prerequisite is missing

- **GIVEN** a packaged Windows host that cannot satisfy a documented `windows_wintun` prerequisite such as driver availability or required privilege
- **WHEN** the operator starts system tunnel mode for `windows_wintun`
- **THEN** startup returns `ready=false`
- **AND** it reports `capability_check` or `driver_acquire` as the failing stage
- **AND** it reports the missing prerequisite explicitly

### Requirement: Desktop ready-path startup protects underlay control traffic and cleans up on failure

The system SHALL validate desktop route exclusion and DNS bypass policy before claiming readiness for any supported desktop mode, and SHALL tear down partial desktop tunnel resources when startup fails after partial progress.
The first supported Windows path SHALL satisfy this rule for TURN underlay, control-plane, provider-challenge, and DNS flows.

#### Scenario: Desktop control-traffic exclusion is unsafe

- **GIVEN** a packaged desktop host starting a supported platform tunnel mode
- **AND** the documented TURN underlay, control-plane, provider-challenge, or DNS bypass exclusions cannot be applied safely
- **WHEN** startup validates the documented desktop route policy for that mode
- **THEN** startup returns `ready=false`
- **AND** it reports `route_validate` as the failing stage
- **AND** it reports `route_exclusion` or `dns_bypass` as the missing prerequisite
- **AND** the host does not claim readiness

#### Scenario: Runtime attach fails after Windows host bring-up

- **GIVEN** a packaged Windows host that has already created the documented Wintun adapter and prepared the route policy
- **WHEN** the host cannot attach the shared runtime to that `windows_wintun` path
- **THEN** startup returns `ready=false`
- **AND** it reports `runtime_attach` as the failing stage
- **AND** the host tears down the partial Windows tunnel resources before returning failure
