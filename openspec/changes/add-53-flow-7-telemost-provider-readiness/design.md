## Context

The current repo truth for Telemost is intentionally narrow: the provider
matrix records `yandex-telemost` only as a legacy path, and the live host
catalog still ships only `vk` and `generic-turn`.

Telemost is also unlike the current TURN-backed production path. A future
Telemost rollout may involve:

- one surface that creates or obtains a joinable conference room
- another surface that lets a shell open that room externally
- an additional, separate surface for repo-owned same-device attachment and
  runtime traffic

Those surfaces must not be collapsed into one optimistic "Telemost works"
claim.

## Goals

- Define one Telemost-specific admission boundary before provider rollout work
  begins.
- Keep legacy references and research outputs non-authoritative for shipped
  support.
- Make the auth split explicit so the product does not treat room creation as
  proof of runtime-attach readiness.

## Non-Goals

- Implement the Telemost provider.
- Commit a same-device Telemost runtime tuple.
- Promote Telemost into the shipped provider catalog.

## Decisions

### Decision: Telemost stays fail-closed until exact support surfaces are reviewed

The repository may contain legacy notes, research findings, or operator-owned
bootstrap assets related to Telemost. None of those by themselves count as
operator-facing support.

### Decision: Room creation and runtime attach are separate support prerequisites

Telemost planning must distinguish:

- conference creation or bootstrap
- ordinary room opening
- repo-owned same-device runtime attach

The product cannot treat success in one of those areas as proof of the others.

### Decision: Telemost does not inherit `generic_turn`

Even if Telemost eventually supports same-device traffic, that support should
not be flattened into `generic_turn` unless a separate transport-ready artifact
exists and is explicitly modeled as such.
