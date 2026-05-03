## Context

Active-standby pathsets improve resilience, but they still leave available
capacity unused on standby paths.

The next additive step is flow sharding:

- multiple child paths can be active concurrently
- one flow stays on one child path at a time
- the scheduler balances flows, not packets
- path selection needs live scores and limit-domain metadata, not just child
  count

That is materially simpler than packet striping and fits the repository's
current framing model better.

## Goals

- Define one honest active-active scheduler that avoids packet striping.
- Keep flow ownership explicit and stable.
- Preserve fail-closed behavior for unsupported sharding mixes.
- Prevent same-ceiling child paths from being presented as bandwidth-diverse.

## Non-Goals

- Packet striping.
- Cross-path packet reorder handling for one flow.
- Guaranteed aggregate throughput claims.

## Decisions

### Decision: Active-active starts with flow sharding

The first concurrent scheduler should be `flow_sharded`, not packet striping.
That keeps one flow on one path and avoids a new global ordering layer.

### Decision: Flow identity must be documented

The runtime must define what a "flow" means for both datagram and stream
traffic. The scheduler should not rely on hidden heuristics.

### Decision: Failover is scoped to affected flows

If one child path fails, the runtime should only remap the affected flows
rather than resetting the whole pathset implicitly.

### Decision: Flow sharding is evidence-scored

`flow_sharded` support must use measured path health, capacity, and
limit-domain classification. If more flows or connections inside one provider
domain no longer improve throughput, the scheduler may keep those paths for
resilience or isolation, but docs and diagnostics must not sell them as
aggregate bandwidth.
