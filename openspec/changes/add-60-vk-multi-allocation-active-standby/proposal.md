# Change: [60] Add VK multi-allocation active-standby runtime

## Why
The current VK-backed runtime already supports `connections >= 1` and launches
multiple supervised transport workers under one logical session.

That plumbing is useful, but it is not yet an honest resilience contract for
same-provider multi-allocation runtime. Today the repository still treats those
workers as a generic supervised pool, and the current UDP ingress dispatches
datagrams across ready workers instead of keeping one explicit active path and
one or more standby paths.

Recent live VK TURN checks also show that increasing connection count no
longer reliably increases throughput: a contour that previously reached about
10 Mbit/s with four connections now stays around 3-4 Mbit/s. This makes the
slice explicitly resilience-first; same-provider VK fan-out is not a current
bandwidth strategy.

Before the repository attempts general multitransport work, it needs one
narrower provider-specific slice that answers a simpler question:

- can one VK session reuse one successful provider resolution
- open two or more same-tuple TURN allocations with the same derived VK
  credentials
- keep one allocation active for payload
- and promote a standby allocation fail-closed when the active one dies

## Sequence
- Order: `60`
- Depends on: the current shipped VK runtime slice and
  `add-16-flow-4-release-verification-vk-derived-expiry-verification`
- Unblocks: a resilience-first same-provider runtime slice before the generic
  `flow-8` multitransport work

## What Changes
- Add a new `vk-multi-allocation-runtime` capability for same-provider,
  same-tuple multiple TURN allocations under one VK runtime session.
- Define the first scheduler narrowly as explicit VK-only `active_standby`
  instead of reinterpreting the current generic `connections > 1` fan-out
  behavior as multipath support.
- Record that VK TURN connection count is no longer accepted as a throughput
  multiplier without fresh live evidence.
- Require one successful VK provider resolution to feed multiple same-tuple
  TURN allocations while keeping one active payload path and one or more
  standby allocations.
- Fail closed when the requested standby allocation count cannot be established
  or maintained according to the committed startup policy.
- Extend the VK compatibility surface so standby promotion and
  allocation-quota failure are both backed by explicit evidence, and so
  throughput-scaling claims stay blocked unless measurements prove them.

## Impact
- Affected specs: `vk-multi-allocation-runtime` (new), `tunnel-client-runtime`,
  `vk-runtime-compatibility`
- Affected code: future `internal/session`, `internal/transport`,
  `internal/overlay`, `cmd/tunnel-client`, VK runtime docs and compatibility
  evidence

## Assumptions
- This slice is VK-only and does not yet generalize to non-VK providers.
- All allocations in the first slice use the same transport tuple:
  provider `vk`, one resolved credential set, one selected `mode`, one
  selected `dtls` posture, one selected ingress adapter, and one selected bind
  target policy.
- The first slice is for resilience and standby promotion, not additive
  throughput claims.
- If VK TURN remains capped at one provider-side throughput ceiling, this
  change should mark that as degraded support rather than trying to hide it
  with more allocations.
