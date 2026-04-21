# Change: [52] Add flow-6 provider expansion smarthome provider

## Why
The repository already has the generic contract needed to describe
camera-style provider results, but it still lacks one provider-specific
contract for the first camera provider candidate.

`RTK Smarthome` has been researched as an authenticated camera or device portal
that yields player or archive access rather than a conference room or TURN
handoff. Flow-6 therefore needs one explicit provider contract for how the
`smarthome` family is advertised, how it enters resolution, and what kind of
artifact it resolves into.

Without that change, future implementation would either guess provider-specific
camera workflow inside shells or lie by flattening camera access into
conference or tunnel semantics.

## Sequence
- Order: `52`
- Depends on: `add-48-flow-6-provider-expansion-shipping-gates`,
  `add-50-flow-6-provider-expansion-camera-stream-actions`
- Unblocks: future `smarthome` implementation and release-verification
  follow-ups

## What Changes
- Add a `smarthome-provider` capability that defines the descriptor, typed
  entry contract, resolution output, and fail-closed behavior for the
  `smarthome` provider family.
- Map successful `smarthome` resolution to `camera_stream` artifacts plus the
  committed camera-stream action surface rather than conference or tunnel
  semantics.
- Keep local media playback, `generic-turn` export, and fake conference actions
  out of scope.
- Require redacted ordinary reads and explicit failure behavior for incomplete,
  blocked, or unsupported `smarthome` flows.

## Impact
- Affected specs: `smarthome-provider` (new)
- Affected code: future `internal/provider/smarthome`, `pkg/clientcontrol`,
  desktop/mobile provider entry flows, provider docs, compatibility fixtures

## Assumptions
- `smarthome` is the stable provider family identifier for this rollout.
- The first slice requires explicit account or device-context posture rather
  than an invite-style guest workflow.
- The first slice does not claim local media playback.
