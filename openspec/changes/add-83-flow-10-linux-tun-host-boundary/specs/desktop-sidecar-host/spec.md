## ADDED Requirements
### Requirement: Packaged Linux desktop hosts acquire `linux_tun` privilege through a repo-owned helper

Packaged Linux desktop hosts SHALL acquire the Linux-native privilege required
for `linux_tun` through a repo-owned helper or equivalent packaged mediation
path instead of requiring the whole desktop shell workflow to run privileged.

#### Scenario: Linux packaged host requests native privilege

- **GIVEN** a packaged Linux desktop host starting the documented `linux_tun`
  workflow
- **WHEN** startup needs Linux-native network privilege
- **THEN** the packaged host reaches that privilege through a repo-owned helper
  or equivalent packaged mediation path
- **AND** the operator does not need to run the Flutter shell itself as root to
  reach the typed startup result

### Requirement: Linux helper cleanup remains host-owned and fail-closed

Packaged Linux desktop hosts SHALL keep helper cleanup inside the host-owned
desktop lifecycle.

#### Scenario: Linux helper exits or startup fails after partial native state

- **GIVEN** a packaged Linux desktop host whose helper has already created
  partial native tunnel state
- **WHEN** startup fails or the helper exits unexpectedly
- **THEN** the packaged desktop host remains responsible for fail-closed
  teardown of that partial Linux-native state
- **AND** the shell does not need helper-specific cleanup logic
