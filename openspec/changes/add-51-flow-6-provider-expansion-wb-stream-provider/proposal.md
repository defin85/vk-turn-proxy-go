# Change: [51] Add flow-6 provider expansion WB Stream provider

## Why
The repository already has the generic contract needed to describe
conference-style provider results, but it still lacks one provider-specific
contract for the first non-VK conference provider candidate.

`WB Stream` has been researched as a provider-owned conference surface rather
than a `generic-turn` handoff. Flow-6 therefore needs one explicit provider
contract for how `wb-stream` is advertised, how it enters resolution, and what
kind of artifact it resolves into.

Without that change, future implementation would either guess WB-specific
workflow inside shells or lie by flattening conference access into tunnel
semantics.

## Sequence
- Order: `51`
- Depends on: `add-48-flow-6-provider-expansion-shipping-gates`,
  `add-49-flow-6-provider-expansion-conference-room-actions`
- Unblocks: future WB implementation and release-verification follow-ups

## What Changes
- Add a `wb-stream-provider` capability that defines the descriptor,
  resolution-entry contract, resolution output, and fail-closed behavior for
  the `wb-stream` provider family.
- Map successful WB resolution to `conference_room` artifacts plus the
  committed conference-room action surface rather than `generic_turn`.
- Keep local conference execution, generic-turn export, and implicit embedded
  browser support out of scope.
- Require redacted ordinary reads and explicit failure behavior for incomplete,
  blocked, or unsupported WB flows.

## Impact
- Affected specs: `wb-stream-provider` (new)
- Affected code: future `internal/provider/wbstream`, `pkg/clientcontrol`,
  desktop/mobile provider entry flows, provider docs, compatibility fixtures

## Assumptions
- `wb-stream` is the stable provider family identifier for this rollout.
- The first slice may require either guest or account-backed entry, but the
  descriptor must make that posture explicit instead of leaving it to shell
  guesses.
- The first slice does not claim same-device conference execution.
