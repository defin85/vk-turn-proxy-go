## MODIFIED Requirements
### Requirement: Desktop GUI shell supervises a compatible local host

The system SHALL ensure that the desktop GUI interacts only with a compatible
local host process. For packaged Linux desktop builds, the compatible local
host SHALL be the unprivileged user-space control plane; Linux native tunnel
privilege failures SHALL be rendered as platform-tunnel startup failures rather
than local-host availability failures.

#### Scenario: Compatible host is not running

- **GIVEN** the desktop GUI starts and no compatible local host is available
- **WHEN** the GUI initializes runtime management
- **THEN** it starts or prompts for the local host explicitly
- **AND** it does not attempt to manage sessions through an unavailable host

#### Scenario: Host version is incompatible

- **GIVEN** the desktop GUI finds a local host with an incompatible
  control-plane version
- **WHEN** compatibility negotiation runs
- **THEN** the GUI reports the incompatibility explicitly
- **AND** it blocks session management until a compatible host is available

#### Scenario: Linux tunnel permission is denied after host startup

- **GIVEN** a packaged Linux GUI is connected to a compatible user-space local
  host
- **WHEN** the operator starts `linux_tun` and helper privilege acquisition is
  denied or unavailable
- **THEN** the GUI keeps the local host in the connected state
- **AND** it renders the platform-tunnel startup result as a permission-stage
  failure with a retry path
- **AND** it does not replace the connected host state with `Local host
  blocked`

#### Scenario: Linux provider browser flow does not require privileged host startup

- **GIVEN** a packaged Linux GUI is connected to the user-space local host
- **WHEN** provider resolution needs a browser continuation before any
  platform-tunnel startup
- **THEN** the GUI can complete the provider flow through the local control
  plane without requiring a Linux privilege prompt
- **AND** browser-start failures are reported as provider-resolution failures,
  not local-host launch failures

