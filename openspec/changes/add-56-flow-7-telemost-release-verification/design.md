## Context

Telemost support claims are only as strong as their most recent live evidence.
Unlike the current deterministic `generic-turn` path, a Telemost rollout may
depend on:

- provider-owned room creation or bootstrap surfaces
- provider-owned room join behavior
- repo-owned attach materialization
- repo-owned runtime traffic over one documented carrier family

Any of those layers can drift independently.

## Goals

- Define the live evidence bar before Telemost support is promoted.
- Keep support claims scoped to exact verified surfaces.
- Prevent community artifacts or stale anecdotes from redefining product truth.

## Non-Goals

- Automate every live Telemost verification step in this change.
- Guarantee perpetual Telemost stability from one successful run.
- Treat shell-external room opening and same-device runtime as one inseparable
  support claim.

## Decisions

### Decision: Telemost support is promoted per verified surface

The repository may eventually verify `open_room` before it verifies a
same-device runtime tuple. Those surfaces should be promoted separately rather
than merged into one all-or-nothing marketing claim.

### Decision: Community proof is research input, not release evidence

Public PoCs, external repos, and community performance anecdotes are useful
for planning but not sufficient for shipped-support claims in this repository.

### Decision: Throughput claims need repo-owned methodology and dates

If the repository claims that one Telemost path is materially faster than the
current production path, that claim should be backed by documented
measurements, exact date, and exact runtime tuple instead of informal chat
numbers.
