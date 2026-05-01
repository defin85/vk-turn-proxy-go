## ADDED Requirements

### Requirement: Desktop hosts gate structured VPN profile editing on real host support

Desktop packaged hosts SHALL advertise structured VPN transport profile editing
only after the desktop host owns the schema, validation, persistence,
redaction, and startup materialization path for the advertised profile kind.

#### Scenario: Packaged desktop host advertises structured WireGuard editing

- **GIVEN** a packaged desktop host advertises structured editing for
  `wireguard_native_v1`
- **WHEN** a shell creates or updates a profile through the structured editor
- **THEN** the host persists the result in the host-owned transport-profile
  store
- **AND** ordinary status, diagnostics, and startup responses remain redacted
- **AND** `windows_wintun` startup materializes the WireGuard execution lease
  from the stored profile id rather than from workstation-local environment or
  default WireGuard paths

#### Scenario: Desktop host lacks structured edit materialization

- **GIVEN** a desktop host can import WireGuard `.conf` files but cannot yet
  validate and materialize structured fields for `windows_wintun`
- **WHEN** it reports transport-profile-store capability metadata
- **THEN** it advertises only import, replace, forget, validate, and
  select-for-startup lifecycle actions
- **AND** it does not advertise structured create/update schemas for that kind
