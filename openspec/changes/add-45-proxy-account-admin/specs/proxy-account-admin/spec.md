## ADDED Requirements

### Requirement: Proxy account admin manages only the documented profile and account set

The system SHALL provide an authenticated VPS-local proxy account admin surface
that manages only an allow-listed set of documented proxy profiles or inbounds
and their client accounts.

#### Scenario: Operator opens the authenticated proxy account admin surface

- **GIVEN** the project VPS hosts the supported proxy account admin capability
- **WHEN** an authenticated operator opens the account-management surface
- **THEN** they can inspect the documented managed profiles and accounts
- **AND** the surface does not expose unrelated host configuration, arbitrary
  shell access, or raw config-file editing as if they were supported account
  management targets

### Requirement: Proxy account admin applies account lifecycle changes through an explicit control boundary

The system SHALL create, update, disable, revoke, or regenerate managed proxy
accounts through documented admin APIs instead of browser-driven shell
execution or manual config-file edits.

#### Scenario: Operator creates a managed proxy account with policy controls

- **GIVEN** a supported managed profile exists on the VPS
- **WHEN** an authenticated operator creates a new account with supported
  enabled-state, expiry, or quota policy
- **THEN** the request runs through the documented VPS-local admin boundary
- **AND** the surface reports explicit success or failure
- **AND** invalid policy or backend rejection fails closed instead of leaving
  the browser with implied success

### Requirement: Proxy account admin surfaces delivery material with redaction and auditability

The system SHALL surface account delivery artifacts and policy state through
documented redaction and audit rules.

#### Scenario: Operator inspects one managed proxy account

- **GIVEN** a managed proxy account exists on the VPS
- **WHEN** an authenticated operator opens that account in the admin surface
- **THEN** the surface shows the account enabled-state together with current
  expiry, quota, or traffic-policy context
- **AND** the documented delivery artifacts, such as links, QR codes, or
  config exports, follow explicit redaction or regeneration rules
- **AND** the system records enough audit context to identify who changed the
  account state or regenerated its delivery material and what result occurred
