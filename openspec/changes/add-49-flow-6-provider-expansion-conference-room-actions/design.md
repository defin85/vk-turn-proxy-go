## Context

The repository already has a generic artifact-family contract, but
`conference_room` is still too abstract for a real shipped provider rollout.
Flow-6 needs one provider-agnostic action surface that conference-style
providers can target without leaking provider-specific raw payloads into the
shells.

## Goals

- Define one stable first-slice action surface for `conference_room`
  artifacts.
- Keep ordinary reads redacted and machine-readable.
- Keep desktop and mobile behavior aligned without reintroducing provider-name
  branching.

## Non-Goals

- Add a same-device conference executor.
- Normalize every possible conference provider into identical UX beyond the
  committed first-slice action surface.
- Expose raw provider room tokens or signaling payloads in ordinary reads.

## Decisions

### Decision: The first conference-room action surface is shell-external

The first committed action is `open_room`, executed through a typed
shell-external navigation target. This keeps the product honest while real
conference execution remains out of scope.

### Decision: Conference-room metadata stays summary-first

Ordinary reads expose only the non-secret room summary and action metadata
needed for operator navigation. Provider-specific raw room/session payloads
remain redacted.

### Decision: Same-device execution stays fail-closed

The repository does not claim local conference execution until a later change
adds a real family-specific executor and verification evidence.
