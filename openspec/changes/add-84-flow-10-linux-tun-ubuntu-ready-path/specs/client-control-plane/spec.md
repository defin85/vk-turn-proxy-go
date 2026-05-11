## ADDED Requirements
### Requirement: Client control plane keeps Linux ready-path evidence inside the canonical desktop startup result

The system SHALL keep Linux packaged desktop startup and readiness evidence
inside the canonical `/v1/platform-tunnels/start` result instead of requiring a
helper-specific follow-up API.

#### Scenario: Linux startup returns typed ready evidence

- **GIVEN** a packaged Linux host reaches `ready=true` for `linux_tun`
- **WHEN** the shell reads the canonical startup result
- **THEN** the result includes the selected execution plan and remote ingress
  diagnostics
- **AND** it includes the canonical platform-tunnel dataplane evidence required
  for ready packaged desktop paths
- **AND** the shell does not call a second helper-specific API to discover that
  readiness
