## ADDED Requirements
### Requirement: Linux packages stage unprivileged host and privileged helper separately

The repository SHALL package the Linux desktop local host launcher and the
Linux `linux_tun` privileged helper as separate artifacts so ordinary local
host startup does not require privilege escalation.

#### Scenario: Ubuntu package stages separate Linux host artifacts

- **GIVEN** the operator builds the documented Ubuntu RelayDock package
- **WHEN** packaging stages the Linux desktop payload
- **THEN** the package contains an unprivileged `clientd` launcher for the
  local control plane
- **AND** it separately contains the privileged `linux_tun` helper and its
  privilege-mediation metadata
- **AND** the local host launcher does not invoke `pkexec`, `sudo`, or an
  askpass helper during ordinary host startup

#### Scenario: Package verification rejects root-host startup as the normal path

- **GIVEN** a Linux package stages a launcher that starts the whole local
  control-plane host as root for ordinary GUI startup
- **WHEN** the repository runs the documented Linux package verification
- **THEN** verification fails before claiming a supported Ubuntu package
- **AND** the failure identifies the broad root-host startup path as a
  packaging-boundary violation

#### Scenario: Helper metadata is tied to the helper artifact

- **GIVEN** the Ubuntu package stages privilege-mediation metadata
- **WHEN** the operator installs the package
- **THEN** the metadata authorizes only the documented Linux TUN helper path
- **AND** it does not authorize the ordinary local host binary as the
  privileged execution target

#### Scenario: Package does not force root-owned profile storage

- **GIVEN** the Ubuntu package stages the unprivileged local host launcher
- **WHEN** package verification inspects normal host startup environment and
  installed defaults
- **THEN** the launcher does not force `VKTP_LINUX_TRANSPORT_PROFILE_STORE` or
  equivalent profile-store configuration to a root-owned package path
- **AND** any legacy root-owned profile-store path is reachable only through a
  documented one-time migration or diagnostic flow
