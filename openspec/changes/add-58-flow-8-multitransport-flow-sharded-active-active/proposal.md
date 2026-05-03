# Change: [58] Add flow-8 multitransport flow-sharded active-active runtime

## Why
`add-57` defines failover-oriented multitransport pathsets, but it still keeps
only one child path active at a time.

That is the right first slice. The next useful step is not packet striping. It
is flow-sharded active-active runtime, where more than one child path can carry
traffic concurrently while each local flow stays pinned to one child path at a
time.

This gives the repository a realistic path toward concurrent transport use
without requiring global packet reordering or striping logic immediately.

The new VK TURN degradation signal also changes what this slice must prove:
flow sharding only has performance meaning when child paths are in sufficiently
independent limit domains. Otherwise it is concurrent scheduling inside one
ceiling, not a bandwidth recovery strategy.

## Sequence
- Order: `58`
- Depends on: `add-57-flow-8-multitransport-active-standby-pathsets`
- Unblocks: `add-59-flow-8-multitransport-packet-striping-research`

## What Changes
- Add a new `flow-sharded-runtime-execution` capability for active-active
  multitransport pathsets that distribute flows across child paths.
- Define the first concurrent scheduler as `flow_sharded`.
- Require stable flow-to-path ownership, explicit failover rules, and
  non-striping semantics.
- Require path scoring and limit-domain evidence before any flow-sharded
  support wording implies additive throughput.
- Keep packet-level striping, global reorder buffers, and aggregate throughput
  guarantees out of scope.

## Impact
- Affected specs: `flow-sharded-runtime-execution` (new)
- Affected code: future `internal/session` schedulers, `internal/overlay`
  flow-key ownership, `pkg/clientcontrol` pathset serialization, runtime docs
  and verification

## Assumptions
- The first active-active slice can shard by flow hash, stream identity, or
  another documented flow key, but not by packet.
- A flow can be reassigned only through documented failover or rebalance
  behavior.
- Child paths remain individually documented execution plans.
- Child paths that share one provider-side throughput ceiling may still carry
  separate flows, but they do not justify aggregate-throughput claims.
