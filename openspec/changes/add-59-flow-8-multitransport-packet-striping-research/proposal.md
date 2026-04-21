# Change: [59] Add flow-8 multitransport packet-striping research boundary

## Why
Packet striping is the tempting final step after active-standby and
flow-sharded active-active runtime, but it is not just a stronger scheduler.
It is a different transport problem.

Once one flow is split across multiple child paths, the repository needs new
connection-level ordering, recovery, congestion, and duplication semantics.
Without an explicit research boundary, the project can drift into overclaiming
"multitransport" while still lacking the machinery that makes striping safe.

## Sequence
- Order: `59`
- Depends on: `add-58-flow-8-multitransport-flow-sharded-active-active`
- Unblocks: a future implementation-only packet-striping change if and only if
  the research and verification bar is met

## What Changes
- Add a new `packet-striping-runtime-research` capability that defines
  packet-striping as research-only until a future reviewed implementation
  change lands.
- Require explicit design and evidence for connection-level sequencing, reorder
  tolerance, duplicate suppression, and congestion strategy before any shipped
  support claim.
- Define kill criteria so throughput anecdotes or one-off demos do not promote
  packet striping into product truth.
- Keep packet striping out of ordinary shipped runtime support in this slice.

## Impact
- Affected specs: `packet-striping-runtime-research` (new)
- Affected code: future `internal/session`, `internal/overlay`, transport
  congestion/recovery work, live verification docs, support-status wording

## Assumptions
- Packet striping is substantially riskier than active-standby or
  flow-sharded runtime.
- Throughput alone is not enough evidence for shipped striping support.
- This slice does not promise that packet striping will be implemented.
