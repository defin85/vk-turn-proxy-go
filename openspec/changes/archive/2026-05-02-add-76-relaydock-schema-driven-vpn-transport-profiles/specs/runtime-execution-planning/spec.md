## MODIFIED Requirements

### Requirement: The first packaged system-tunnel ready paths stay intentionally narrow

The system SHALL keep the first packaged Android and desktop system-tunnel
support claims scoped to documented TURN-backed `wireguard_native` execution
plans until later changes add and verify additional engine families and their
required transport profile kinds explicitly.

#### Scenario: First packaged system-tunnel path remains `wireguard_native`

- **GIVEN** a packaged host that reaches `ready=true` for one documented
  platform tunnel mode
- **WHEN** the host reports the supported same-device execution plans for that
  mode
- **THEN** the supported packaged system-tunnel plan is explicitly documented
  as TURN-backed and `wireguard_native`
- **AND** the host does not imply that `webrtc_datachannel`,
  `proxy_core_adapter`, `trusttunnel_native`, or another engine family is also
  supported for that same mode
- **AND** the presence of an editable non-WireGuard transport profile schema
  does not by itself make that profile kind a startable system-tunnel plan

## ADDED Requirements

### Requirement: Runtime plans bind transport profile kinds explicitly

Runtime execution plans that require VPN transport material SHALL declare the
specific transport profile kind or kinds they can materialize.

#### Scenario: Non-WireGuard profile kind requires a matching plan

- **GIVEN** a host advertises an editable profile kind other than
  `wireguard_native_v1`
- **WHEN** the host reports runtime execution plans
- **THEN** that profile kind becomes startable only if a supported plan declares
  it as a required profile kind for the selected access method, carrier family,
  engine family, and host adapter
- **AND** startup fails closed if the caller requests the profile kind through a
  plan that does not declare that compatibility edge

#### Scenario: Editable profile is not startable

- **GIVEN** a host advertises structured editing for a future profile kind
- **AND** the current build has no materializer or native adapter for that kind
- **WHEN** the shell evaluates VPN startup readiness
- **THEN** the shell reports setup or support state without enabling primary
  connect
- **AND** the host does not substitute a WireGuard plan or another engine family
  implicitly
