# Change: [53] Add flow-7 Telemost provider readiness boundary

## Why
The repository already mentions `yandex-telemost` in the provider matrix, but
only as a legacy-only path that must not be treated as an active product
target.

That is the right current truth, but it is not yet backed by one explicit
Telemost-specific readiness contract. Without that boundary, future work can
blur together three different things:

- room creation through an official or operator-owned surface
- ordinary room opening through a conference-style artifact
- same-device runtime attachment through a repo-owned carrier

Telemost needs its own first change so the product does not treat room
creation, community PoCs, or a room URL as proof of shipped provider support.

## Sequence
- Order: `53`
- Depends on: `add-20-multi-provider-runtime-families`,
  `update-23-app-owned-provider-catalog`
- Unblocks: `add-54-flow-7-telemost-provider-contract`,
  `add-55-flow-7-telemost-video-frame-carrier`,
  `add-56-flow-7-telemost-release-verification`

## What Changes
- Add a `telemost-provider-readiness` capability that defines the admission
  boundary from legacy Telemost traces into reviewed product support.
- Keep `yandex-telemost` fail-closed until the repository has both a committed
  provider contract and repo-owned release verification for the exact claimed
  support surface.
- Require Telemost planning to distinguish room-creation prerequisites from
  join or runtime-attach prerequisites instead of treating one auth surface as
  proof of the other.
- Keep Telemost out of `generic_turn` semantics unless a separate
  transport-ready artifact exists.

## Impact
- Affected specs: `telemost-provider-readiness` (new)
- Affected code: future provider rollout gates in `pkg/clientcontrol`,
  supported-provider catalog exposure, provider docs, release evidence

## Assumptions
- The stable provider identifier remains `yandex-telemost` unless a later
  approved change renames it deliberately.
- Existing legacy references are not authoritative for shipped support.
- The first Telemost slices may land as room-open support before any
  same-device runtime support is approved.
