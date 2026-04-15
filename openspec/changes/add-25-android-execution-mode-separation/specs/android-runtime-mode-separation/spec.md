## ADDED Requirements
### Requirement: Android system-tunnel and non-system relay modes stay explicit

The system SHALL treat Android `android_vpn_service` behavior and any future
non-system Android relay mode as separate operator-visible runtime modes.

#### Scenario: Android system tunnel stays explicit

- **GIVEN** an Android runtime mode whose host adapter is
  `android_vpn_service`
- **WHEN** the repository documents or renders that mode
- **THEN** it is described as an Android system-tunnel mode
- **AND** it is not relabeled as a generic proxy-only or hidden relay mode

#### Scenario: Future non-system Android mode is proposed

- **GIVEN** a future Android runtime that does not rely on
  `android_vpn_service`
- **WHEN** the repository proposes that runtime
- **THEN** it uses its own documented execution plan and operator-facing mode
- **AND** it does not inherit support claims from `android_vpn_service`

### Requirement: Reduced detection-surface claims require explicit review

The system SHALL require explicit threat-model review before any future Android
mode may claim a different or smaller detection surface than
`android_vpn_service`.

#### Scenario: Future proposal claims a smaller Android detection surface

- **GIVEN** a future Android proposal that claims a different or smaller
  detection surface than the documented `android_vpn_service` path
- **WHEN** that proposal is reviewed
- **THEN** it includes an explicit threat model, acceptance criteria, and
  evidence plan for that claim
- **AND** it does not inherit approval from the existence of the honest Android
  VPN mode alone
