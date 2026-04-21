## ADDED Requirements
### Requirement: Proxy-only mode stays separate from Android system-tunnel mode

The system SHALL treat the first Android proxy-only mode as a distinct
operator-visible non-system runtime instead of inheriting the semantics of
`android_vpn_service`.

#### Scenario: Repository documents both Android modes

- **GIVEN** a repository state that documents both `android_vpn_service` and
  proxy-only mode
- **WHEN** those modes are described in docs, specs, or UI
- **THEN** proxy-only mode remains a separate non-system Android mode
- **AND** it does not inherit support or stealth assumptions from
  `android_vpn_service`
