## ADDED Requirements

### Requirement: VPS admin web manages only the documented server runtime set

The system SHALL provide an authenticated VPS-local web admin surface that
manages only an allow-listed set of repo-owned server runtimes.

#### Scenario: Operator opens the authenticated VPS admin surface

- **GIVEN** the project VPS hosts the supported server admin web
- **WHEN** an authenticated operator opens the browser surface
- **THEN** they can inspect the documented managed services and their current
  status
- **AND** the surface does not expose arbitrary shell access or unrelated host
  processes as if they were supported management targets

### Requirement: VPS admin web shows build and operational state from supported signals

The system SHALL surface managed-service build identity and operational state
from documented build and observability signals instead of requiring manual SSH
inspection for routine health checks.

#### Scenario: Operator inspects one managed service

- **GIVEN** a managed server service is installed on the VPS
- **WHEN** the operator opens that service in the admin web
- **THEN** the surface shows the current build identity, lifecycle state, and
  recent health context for that service
- **AND** it can expose recent logs or metrics summaries without surfacing raw
  secrets as operator-visible status

### Requirement: VPS admin web performs explicit lifecycle actions with auditability

The system SHALL execute supported lifecycle actions through an explicit
service-control boundary and retain enough action context for operator follow-up.

#### Scenario: Operator restarts a managed service

- **GIVEN** an authenticated operator has access to one managed service in the
  admin web
- **WHEN** they request a supported lifecycle action such as restart
- **THEN** the action runs through the documented management boundary instead of
  browser-driven shell execution
- **AND** the surface reports success or failure explicitly
- **AND** the system records enough audit context to identify who requested the
  action and what result occurred
