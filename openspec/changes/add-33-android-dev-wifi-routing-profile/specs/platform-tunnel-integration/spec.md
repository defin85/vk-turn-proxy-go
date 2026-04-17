## ADDED Requirements
### Requirement: Platform tunnel startup accepts explicit underlay-route policies

The system SHALL treat application-routing scope and underlay-route preservation
as separate startup concerns for supported platform tunnel modes.

#### Scenario: Android system tunnel preserves the active local network for development

- **GIVEN** a supported `android_vpn_service` host
- **AND** the caller requests the typed underlay-route policy
  `preserve_active_local_network`
- **WHEN** platform tunnel startup prepares routes for that mode
- **THEN** the host preserves the active local underlay network outside the
  tunnel for development or control traffic
- **AND** the mode remains the documented Android system-tunnel mode rather
  than a different runtime mode
- **AND** application-routing policy continues to apply independently of the
  underlay-route policy

#### Scenario: Standard profile keeps normal route preparation

- **GIVEN** a supported platform tunnel mode
- **WHEN** the caller uses the default underlay-route policy
  `standard`
- **THEN** startup keeps the normal route-preparation behavior for that mode
- **AND** it does not imply local-network preservation unless the caller
  requested it explicitly

### Requirement: Platform tunnel startup fails closed for unsupported underlay-route policies

The system SHALL reject unsupported or unsafe underlay-route policy requests
explicitly instead of silently downgrading them.

#### Scenario: Host does not support the requested underlay-route policy

- **GIVEN** a caller requests a typed underlay-route policy that the current
  host does not advertise for the requested mode
- **WHEN** startup validation runs
- **THEN** startup fails closed with an explicit typed failure
- **AND** the host does not silently replace the request with `standard`

#### Scenario: Requested local-network preservation cannot be prepared safely

- **GIVEN** the caller requests `preserve_active_local_network`
- **WHEN** the host cannot determine or apply the required route exclusions for
  the active underlay network
- **THEN** startup fails before readiness is reported
- **AND** the failure identifies route preparation or route exclusion as the
  responsible prerequisite
