## Context

The repository's current overlay and session model can route traffic across
workers, but it does not yet define one global sequence space or reorder
strategy across multiple child paths for the same flow.

That makes packet striping a qualitatively different change from failover or
flow sharding. Before implementation, the repository needs one explicit
research-only boundary.

Recent VK TURN throughput behavior adds another research constraint: adding
more paths inside one provider policy domain can stop improving throughput.
Striping research must therefore prove path independence, not only packet
ordering correctness.

## Goals

- Prevent packet striping from being overclaimed as if it were the same as
  generic multitransport support.
- Define the minimum design and evidence bar required before implementation.
- Keep the current support story honest.
- Require evidence that child paths are not all capped by one shared
  throughput ceiling before claiming bandwidth recovery.

## Non-Goals

- Implement packet striping.
- Promise that striping will ship.
- Treat throughput anecdotes as sufficient proof.

## Decisions

### Decision: Packet striping remains research-only in this slice

This change exists to make the boundary explicit, not to smuggle striping into
shipped support.

### Decision: Striping readiness requires transport-level machinery

Any future striping implementation must define:

- one global sequence or equivalent ordering contract
- reorder tolerance or buffering rules
- duplicate suppression rules
- congestion or pacing strategy across child paths

### Decision: Kill criteria matter as much as optimistic metrics

If a striping design cannot control reorder, duplication, or congestion
collapse within documented budgets, the repository should keep it out of
product support regardless of anecdotal throughput gains.

### Decision: Same-ceiling striping is a kill criterion for bandwidth claims

If live tests show that striped child paths share one provider-side ceiling,
the result can still inform resilience or diagnostics work, but it must not
promote packet striping into a bandwidth feature.
