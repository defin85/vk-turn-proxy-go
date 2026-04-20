## ADDED Requirements

### Requirement: Mobile GUI keeps platform-tunnel activity aligned with sessions

The system SHALL present VPN-backed runtime activity through the same mobile
activity/session surface as other same-device runtime attempts instead of
forcing the operator to infer runtime state from VPN indicators or resolution
counts alone.

#### Scenario: Ready VPN-backed runtime appears in mobile activity

- **GIVEN** the operator starts a supported mobile platform-tunnel mode from
  the mobile shell
- **AND** the connected host reports `ready=true` for a runtime-backed startup
- **WHEN** the shell refreshes its activity surfaces
- **THEN** the corresponding runtime appears in the mobile `Sessions` surface
- **AND** the operator can reach ordinary session actions such as stop or
  diagnostics from that session entry
- **AND** the shell does not require the operator to treat `Resolutions` or a
  raw VPN indicator as the only proof that runtime exists

#### Scenario: Mobile shell selects the resulting runtime session after ready startup

- **GIVEN** the control plane returns a `session_id` for a successful mobile
  platform-tunnel startup or resume
- **WHEN** the shell completes that workflow
- **THEN** it refreshes the relevant mobile activity and support surfaces
- **AND** it may use that returned `session_id` to focus the resulting runtime
  entry without guessing from unrelated session updates
