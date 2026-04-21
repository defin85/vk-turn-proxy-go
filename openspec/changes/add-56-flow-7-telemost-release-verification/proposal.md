# Change: [56] Add flow-7 Telemost release verification

## Why
Telemost is more drift-prone than the current TURN-backed production path. Its
candidate support surface depends on provider-owned room, auth, attach, and
media behavior that may change independently from our repository.

That makes a normal unit or local-only verification story insufficient for any
real Telemost support claim. The repository needs one explicit release
verification contract before it promotes Telemost beyond research or legacy
status.

## Sequence
- Order: `56`
- Depends on: `add-48-flow-6-provider-expansion-shipping-gates`,
  `add-54-flow-7-telemost-provider-contract`,
  `add-55-flow-7-telemost-video-frame-carrier`
- Unblocks: Telemost support promotion from legacy-only or experimental status
  into reviewed provider rollout for the exact verified surfaces

## What Changes
- Add a `telemost-release-verification` capability that defines the evidence
  required before the repository claims ordinary Telemost support.
- Require repo-owned live verification for each committed Telemost surface
  separately, including shell-external room opening and any same-device runtime
  tuple.
- Keep community PoCs, anecdotal throughput numbers, and one-off room-join
  success explicitly non-authoritative for shipped support claims.
- Require throughput or resilience claims to be backed by documented,
  date-stamped repo-owned verification instead of chat-level anecdotes.

## Impact
- Affected specs: `telemost-release-verification` (new)
- Affected code: future release docs, provider rollout gates, compatibility or
  live verification fixtures, provider matrix/support-status docs

## Assumptions
- Telemost support may graduate in slices; `open_room` and same-device runtime
  do not have to ship together.
- Support claims must be scoped to exact verified auth posture and runtime
  tuple.
- Upstream Telemost behavior may drift and must not be hidden behind stale
  support wording.
