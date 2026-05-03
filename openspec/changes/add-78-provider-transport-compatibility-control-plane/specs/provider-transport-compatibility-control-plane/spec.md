## ADDED Requirements
### Requirement: Host exposes provider/transport compatibility candidates

The system SHALL expose a host-owned provider/transport compatibility read
model that combines provider source or resolved artifact state with VPN
transport profile state and runtime execution planning.

#### Scenario: Shell reads candidates for selected source and transport profile

- **GIVEN** a compatible host with runtime execution planning,
  provider-runtime artifacts, and VPN transport profile store support
- **AND** the shell has selected or resolved one provider/source side
- **AND** the shell has selected one VPN transport profile or needs one
  required profile kind
- **WHEN** the shell reads provider/transport compatibility candidates
- **THEN** the host returns candidates with source or artifact reference,
  runtime execution plan identity, required profile kind, selected profile
  reference when present, support state, failing axis, and reason metadata
- **AND** the shell does not need to infer compatibility from provider names,
  profile kinds, or display labels alone

### Requirement: Compatibility status is explicit and fail-closed

The system SHALL report blocked provider/transport combinations with typed
status and failing-axis metadata before startup can claim readiness.

#### Scenario: Combination is not startable

- **GIVEN** a provider/source and VPN transport profile combination is
  unsupported, missing setup, stale, degraded, missing evidence, or unavailable
  on the current host
- **WHEN** the shell reads compatibility candidates or requests startup
- **THEN** the host reports a non-startable status
- **AND** the response identifies the failing axis such as provider_source,
  artifact_access_method, carrier_family, engine_family, host_adapter,
  transport_profile, degraded_policy, evidence, or host_capability
- **AND** the host does not silently substitute another provider source,
  execution plan, host adapter, or VPN transport profile

#### Scenario: Compatibility response uses stable status and axis values

- **GIVEN** the host returns provider/transport compatibility candidates
- **WHEN** it serializes status and failing-axis metadata
- **THEN** status uses the documented values `startable`, `setup_needed`,
  `unsupported`, `stale`, `degraded`, `missing_evidence`, or `unavailable`
- **AND** failing axis uses the documented values `provider_source`,
  `provider_artifact`, `artifact_access_method`, `carrier_family`,
  `engine_family`, `host_adapter`, `transport_profile`, `degraded_policy`,
  `evidence`, or `host_capability`
- **AND** unknown future status or axis values are reported with explicit
  extension metadata and treated as non-startable by shells that do not
  understand them
- **AND** display labels or localized text are not the compatibility contract

### Requirement: Startup revalidates the selected candidate

The system SHALL revalidate the selected provider/transport candidate during
startup because source and transport state can change after the read-model
response.

#### Scenario: Candidate becomes stale before startup

- **GIVEN** a compatibility candidate was previously reported as startable
- **AND** its provider resolution expires, its selected transport profile is
  forgotten or edited incompatibly, or the host capability changes before
  startup
- **WHEN** the shell requests startup using that candidate
- **THEN** startup fails closed before readiness
- **AND** the failure response names the stale axis and reason
- **AND** the host does not fall back to a newer provider resolution or another
  compatible transport profile without explicit operator selection
