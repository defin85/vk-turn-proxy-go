## ADDED Requirements

### Requirement: Client control plane exposes VPN transport profile store capability

The system SHALL expose VPN transport profile store support through versioned
client-control-plane capability metadata and typed profile-store operations.

#### Scenario: Updated shell negotiates profile-store support

- **GIVEN** a shell build expects host-owned VPN transport profiles
- **WHEN** it negotiates with a host
- **THEN** the host advertises whether profile-store operations are supported
- **AND** it reports supported profile kinds, import adapters, lifecycle
  actions, and redaction guarantees
- **AND** the shell fails closed or suppresses profile-store UX when the host
  lacks that capability

#### Scenario: Shell imports profile material through a typed action

- **GIVEN** a compatible host advertises one or more profile import adapters
- **WHEN** the shell imports material through a supported adapter
- **THEN** the request names the adapter and target profile kind explicitly
- **AND** the host returns a redacted profile status with a stable profile id
- **AND** the response does not expose the stored raw material or platform path

### Requirement: Client control plane reports transport profile failures with typed startup semantics

The system SHALL represent missing or invalid VPN transport profile material
with typed prerequisite and startup-stage values, such as
`missing_prerequisite=transport_profile` and `stage=profile_validate`, instead
of collapsing the failure into generic host implementation errors.

#### Scenario: Startup fails because the profile is missing

- **GIVEN** a selected execution plan requires a VPN transport profile
- **AND** no compatible profile reference or scoped default is available
- **WHEN** platform tunnel startup validation runs
- **THEN** the startup result reports `missing_prerequisite=transport_profile`
- **AND** the failure stage reports `profile_validate` rather than native
  adapter bring-up or runtime attach

#### Scenario: Startup fails because the profile reference is invalid

- **GIVEN** the shell sends a stale, forgotten, or incompatible transport
  profile reference
- **WHEN** platform tunnel startup validation runs
- **THEN** the startup result reports `missing_prerequisite=transport_profile`
  with a redacted incompatibility message
- **AND** the host does not remap that failure to `host_implementation`

### Requirement: Platform tunnel startup uses transport profile references

The system SHALL carry required VPN transport material into startup through a
profile reference or a host-reported scoped default profile reference instead
of raw config text, private keys, or shell-visible filesystem paths.

#### Scenario: Shell starts a tunnel with a selected profile reference

- **GIVEN** a runtime execution plan requires a configured transport profile
- **AND** the shell has selected a compatible profile id reported by the host
  or the host reports a scoped default profile reference for that exact plan
- **WHEN** the shell requests platform tunnel startup through the control plane
- **THEN** the request carries the selected profile reference
- **AND** the host materializes any secret-bearing startup lease internally
- **AND** ordinary startup responses remain redacted

#### Scenario: Shell sends stale profile reference

- **GIVEN** the shell requests startup with a profile id that was forgotten,
  replaced incompatibly, or is no longer valid for the selected plan
- **WHEN** the host validates startup
- **THEN** startup fails closed with a typed profile prerequisite error
- **AND** the host does not fall back to another profile or a hidden packaged
  seed
