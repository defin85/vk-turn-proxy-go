# Change: [57] Add flow-8 multitransport active-standby pathsets

## Why
The current runtime contract can describe more than one execution plan, but it
still selects one plan for one same-device startup.

That is enough for explicit single-path runtime truth, but not enough for
multitransport failover. The repository needs one additive slice that can keep
one logical runtime session alive across more than one documented child path
without pretending that this already means packet striping or bandwidth
aggregation.

Recent VK TURN observations make the boundary sharper: increasing connection
count inside one provider policy domain no longer reliably increases
throughput. Pathsets therefore need to describe failure and throughput limit
domains explicitly instead of treating child-path count as transport diversity.

## Sequence
- Order: `57`
- Depends on: `add-22-runtime-execution-planning`
- Unblocks: `add-58-flow-8-multitransport-flow-sharded-active-active`,
  `add-59-flow-8-multitransport-packet-striping-research`

## What Changes
- Add a new `multi-transport-runtime-pathsets` capability that defines one
  logical runtime session as an explicit ordered pathset of child execution
  plans.
- Define the first pathset scheduler narrowly as `active_standby`.
- Require each child path to remain an individually documented and
  compatibility-gated execution plan.
- Require child paths to declare their failure/limit-domain relationship so
  same-provider fan-out is not reported as bandwidth-diverse multitransport
  without live evidence.
- Keep packet striping, per-packet scheduling, and aggregate throughput claims
  out of scope for this slice.

## Impact
- Affected specs: `multi-transport-runtime-pathsets` (new)
- Affected code: future `pkg/clientcontrol` runtime-plan serialization,
  `internal/session` scheduler/supervision, `internal/overlay` route
  ownership, runtime docs and verification

## Assumptions
- The first multitransport slice keeps one logical session identity.
- The first slice promotes one standby path only after explicit health failure
  or documented degradation/unavailability of the active path.
- Heterogeneous child plans must stay explicitly compatibility-gated instead of
  being synthesized heuristically.
- Multiple child paths that share the same provider/call/TURN policy ceiling
  can still be useful for resilience, but they are not evidence of additive
  bandwidth.
