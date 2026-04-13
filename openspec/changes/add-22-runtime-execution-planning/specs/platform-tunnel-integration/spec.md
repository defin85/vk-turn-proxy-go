## ADDED Requirements
### Requirement: Platform tunnel support claims are execution-plan-specific

The system SHALL scope platform tunnel support claims to the documented runtime execution plans that a packaged host actually supports for that mode.
Support for one packaged system-tunnel plan SHALL NOT imply support for another engine or carrier family on the same host adapter.

#### Scenario: Supported platform tunnel mode does not imply non-TURN execution

- **GIVEN** a packaged host that supports one documented platform tunnel mode through a TURN-backed `wireguard_native` execution plan
- **WHEN** the client queries platform tunnel support for that mode
- **THEN** the host reports support only for that documented execution plan
- **AND** it does not imply that `webrtc_datachannel`, `proxy_core_adapter`, `trusttunnel_native`, or another carrier or engine family is also supported on that same host adapter

#### Scenario: Packaged host lacks the requested execution plan

- **GIVEN** a platform tunnel mode whose host adapter exists on the current build
- **AND** the current build does not satisfy the documented execution-plan prerequisites for the requested carrier or engine family
- **WHEN** startup validation checks that plan
- **THEN** startup fails before `ready=true`
- **AND** the failure keeps the unsupported execution plan explicit instead of falling back to a guessed system-tunnel path
