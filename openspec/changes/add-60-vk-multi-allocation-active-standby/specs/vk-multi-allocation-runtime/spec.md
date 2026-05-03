## ADDED Requirements
### Requirement: VK multi-allocation runtime is explicit and provider-scoped

The system SHALL expose same-provider VK multi-allocation runtime as an
explicit supported policy instead of treating generic supervised workers as
proof of VK multipath support.

#### Scenario: Operator selects VK active-standby runtime

- **GIVEN** a VK-backed runtime slice that supports explicit
  `active_standby` multi-allocation startup
- **WHEN** the operator selects that policy for one supported VK transport
  tuple
- **THEN** the runtime uses one successful VK provider resolution for that
  session attempt
- **AND** it attempts to establish one active TURN allocation plus the
  requested number of same-tuple standby allocations
- **AND** it does not describe that runtime as generic provider-agnostic
  multitransport support

### Requirement: VK multi-allocation startup fails closed on partial standby bring-up

The system SHALL fail explicitly before readiness when the requested VK
active-plus-standby allocation set cannot be established.

#### Scenario: Requested standby count exceeds current VK allocation allowance

- **GIVEN** an operator requests one active allocation plus one or more
  standby allocations for one supported VK transport tuple
- **WHEN** the VK TURN path rejects one of those standby allocations because
  of quota, capacity, or another transport-stage failure
- **THEN** the runtime fails before `ready=true`
- **AND** it reports the failing startup stage explicitly
- **AND** it does not silently degrade to fewer established allocations than
  the requested policy

### Requirement: VK multi-allocation support claims stay resilience-scoped

The system SHALL keep the first VK multi-allocation support claim scoped to
standby promotion and failover rather than additive throughput.

#### Scenario: Operator docs describe VK multi-allocation support

- **GIVEN** the repository reports support for VK multi-allocation
  `active_standby` runtime
- **WHEN** that support appears in provider docs, runtime docs, or release
  verification artifacts
- **THEN** the claim is scoped to one active allocation plus standby promotion
- **AND** it does not imply active-active scheduling or aggregate bandwidth
  across allocations

### Requirement: VK connection count is an explicit throughput evidence gate

The system SHALL treat VK TURN connection or allocation count as a measured
compatibility property, not as an assumed throughput multiplier.

#### Scenario: Multiple VK connections stop scaling throughput

- **GIVEN** live compatibility evidence compares one VK TURN connection or
  allocation against multiple same-provider connections or allocations
- **WHEN** those measurements converge to the same observed throughput ceiling
- **THEN** VK multi-allocation support remains scoped to resilience and
  standby promotion
- **AND** the repository records the contour as throughput-degraded for
  bandwidth recovery
- **AND** it does not recommend increasing VK connection count as the product
  transport pivot
