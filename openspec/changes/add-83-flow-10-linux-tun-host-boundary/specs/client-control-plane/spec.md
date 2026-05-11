## ADDED Requirements
### Requirement: Client control plane surfaces Linux helper privilege denial through canonical desktop startup results

The system SHALL keep Linux helper privilege mediation behind the canonical
desktop startup API instead of exposing a second helper-specific permission
surface.

#### Scenario: Linux helper privilege acquisition is denied

- **GIVEN** a packaged Linux host starts `linux_tun` through the canonical
  `/v1/platform-tunnels/start` flow
- **AND** the repo-owned helper requires operator-approved privilege mediation
- **WHEN** that mediation is denied or unavailable
- **THEN** startup returns `ready=false`
- **AND** it reports `permission_acquire` as the failing stage
- **AND** it reports `permission` as the missing prerequisite
- **AND** the shell does not need a helper-specific control-plane method to
  understand that failure
