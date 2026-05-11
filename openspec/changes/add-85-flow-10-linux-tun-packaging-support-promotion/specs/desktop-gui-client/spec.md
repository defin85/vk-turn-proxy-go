## ADDED Requirements
### Requirement: Desktop GUI keeps Linux system-tunnel support explicit and target-specific

The desktop GUI SHALL treat `linux_tun` support as a packaged-target-specific
host capability instead of assuming that every Linux desktop build can start a
repo-owned VPN path.

#### Scenario: Packaged Ubuntu host reports a supported `linux_tun` mode

- **GIVEN** a packaged Linux desktop build for the documented supported Ubuntu
  target
- **AND** its bundled host reports `linux_tun` as supported
- **WHEN** the operator opens the desktop tunnel workflow
- **THEN** the GUI may offer the documented `linux_tun` startup action for that
  target
- **AND** it continues to treat other Linux desktop builds as unsupported until
  their packaged host reports that mode honestly
