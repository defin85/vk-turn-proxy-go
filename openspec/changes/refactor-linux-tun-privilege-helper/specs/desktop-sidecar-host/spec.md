## MODIFIED Requirements
### Requirement: Packaged Linux desktop hosts acquire `linux_tun` privilege through a repo-owned helper

Packaged Linux desktop hosts SHALL run the ordinary local control plane,
provider resolution, browser continuation, profile storage, and execution-plan
orchestration as the operator user, and SHALL acquire the Linux-native
privilege required for `linux_tun` only through a repo-owned helper or
equivalent packaged mediation path during platform-tunnel startup.

#### Scenario: Linux packaged host starts without privilege

- **GIVEN** a packaged Linux desktop installation
- **WHEN** the desktop GUI starts its sibling local host
- **THEN** the local host starts as the operator user without requiring a
  password prompt
- **AND** `/v1/host`, provider catalog discovery, profile management,
  provider resolution, and diagnostics remain available before `linux_tun`
  privilege is requested

#### Scenario: Linux packaged host requests native privilege only for tunnel startup

- **GIVEN** the packaged Linux local host is already reachable
- **WHEN** the operator starts the documented `linux_tun` workflow
- **THEN** the host reaches Linux-native privilege through the repo-owned
  helper or equivalent packaged mediation path
- **AND** the operator does not need to run the Flutter shell or the whole
  local control plane as root to reach the typed startup result

#### Scenario: Browser-assisted provider continuation stays user-owned

- **GIVEN** a packaged Linux desktop host that supports browser-assisted
  provider continuation
- **WHEN** provider resolution opens a controlled or owned browser session
- **THEN** the browser session is launched from the operator user context
- **AND** it does not depend on root-owned browser profiles, root Xauthority
  bridging, or a privileged local host process

