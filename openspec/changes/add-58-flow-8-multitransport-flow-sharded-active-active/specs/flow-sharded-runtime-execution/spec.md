## ADDED Requirements
### Requirement: Flow-sharded pathsets distribute flows across active child paths

The system SHALL let one active-active pathset distribute runtime flows across
more than one active child path while keeping each flow pinned to one child
path at a time.

#### Scenario: Host advertises a flow-sharded pathset

- **GIVEN** a resolved artifact and a host build that can support concurrent
  use of more than one child execution plan in one multitransport pathset
- **WHEN** the host reports the available same-device execution surface
- **THEN** it may advertise a pathset whose scheduler policy is
  `flow_sharded`
- **AND** the pathset names the eligible child execution plans explicitly
- **AND** the host does not describe that scheduler as packet striping

### Requirement: Flow ownership stays stable until documented remap

The system SHALL keep each runtime flow on one child path until a documented
rebalance or failover reason applies.

#### Scenario: Flow remains pinned to its assigned child path

- **GIVEN** a running pathset whose scheduler policy is `flow_sharded`
- **WHEN** one local flow has already been assigned to one child path
- **THEN** subsequent packets or stream frames for that flow continue to use
  that same child path
- **AND** the runtime does not stripe that flow across multiple child paths

#### Scenario: Child-path failure remaps only affected flows

- **GIVEN** a running `flow_sharded` pathset with flows assigned across more
  than one child path
- **WHEN** one child path becomes unavailable according to the committed health
  policy
- **THEN** the runtime may remap the flows that were assigned to that failed
  child path
- **AND** it does not imply that unaffected flows were already using the failed
  child path concurrently

### Requirement: Flow sharding bases throughput claims on scored independent paths

The system SHALL evaluate `flow_sharded` throughput claims using documented
path scores and limit-domain classification rather than the number of child
paths alone.

#### Scenario: Child paths share one observed throughput ceiling

- **GIVEN** a `flow_sharded` pathset whose child paths share one provider,
  call, TURN policy, or traffic-class limit domain
- **AND** live evidence shows that additional connections or allocations do
  not increase throughput for that contour
- **WHEN** the host reports the pathset or operator docs describe support
- **THEN** the support claim does not promise additive throughput
- **AND** diagnostics or evidence identify the shared throughput limit domain
- **AND** the scheduler may still use those child paths only for documented
  flow isolation, resilience, or failover behavior

### Requirement: Flow-sharded support does not imply packet striping

The system SHALL keep flow-sharded active-active support distinct from
packet-level striping.

#### Scenario: Flow-sharded runtime is reported as supported

- **GIVEN** a host build that supports one `flow_sharded` pathset
- **WHEN** that support is reported through the host contract or operator docs
- **THEN** the support claim is scoped to per-flow concurrent path use
- **AND** it does not imply packet striping, cross-path packet reordering, or
  guaranteed additive throughput
