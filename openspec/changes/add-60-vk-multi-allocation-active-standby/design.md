## Context

The current repo-owned VK runtime already has most of the low-level plumbing
for multiple workers:

- one logical session identity
- one provider resolution before transport startup
- multiple supervised transport workers
- one ingress that can route traffic toward ready workers

What it does not yet have is an honest same-provider resilience contract.
Today `connections > 1` is still generic worker fan-out, not an explicit
provider-scoped active/standby runtime policy.

This change exists to define one narrower first step before generic
multitransport work:

- same provider: `vk`
- same transport tuple
- one active payload allocation
- one or more standby allocations
- explicit promotion and explicit failure semantics

## Goals

- Define one explicit VK-only multi-allocation resilience slice.
- Keep the first scheduler narrow as `active_standby`.
- Preserve one provider resolution and one logical session identity.
- Fail closed on partial standby bring-up or quota failure.

## Non-Goals

- General multitransport support across different carriers or providers.
- Packet striping or active-active same-flow scheduling.
- Aggregate throughput claims from multiple VK allocations.

## Decisions

### Decision: `active_standby` is explicit and opt-in

The repository should not silently reinterpret the current generic
`connections > 1` worker pool as multipath support.

Instead, VK multi-allocation support should be an explicit runtime policy so
existing supported behavior and future resilience behavior remain
distinguishable.

### Decision: The first slice stays same-provider and same-tuple

This change is intentionally narrower than generic multipath:

- one provider: `vk`
- one resolved credential set
- one selected transport tuple
- multiple TURN allocations under that same tuple

That keeps the problem tractable and aligned with the current VK runtime.

### Decision: Partial standby bring-up fails closed

If the operator explicitly requests active plus standby allocations, the
runtime should not silently degrade to a smaller pool. Allocation quota or
capacity failure must stay visible in startup behavior and support claims.

### Decision: Support claims stay resilience-first

Even if multiple allocations exist, the first supported claim is standby
promotion and failure recovery. The repository should not imply additive
throughput until a later slice proves that separately.
