## Context

Flow-6 includes at least one camera-style provider candidate whose resolved
artifact is neither a tunnel handoff nor a conference room. The product needs
one provider-agnostic camera action surface before it can ship that family
without shell-specific hacks.

## Goals

- Define one stable first-slice action surface for `camera_stream` artifacts.
- Keep ordinary reads redacted and machine-readable.
- Keep desktop and mobile behavior aligned without provider-name branching.

## Non-Goals

- Add a same-device media-player executor.
- Normalize every possible camera/archive product into identical UX beyond the
  first committed action surface.
- Expose raw player or stream tokens in ordinary reads.

## Decisions

### Decision: The first camera-stream action surface is navigation-first

The first committed actions are shell-external navigation targets such as
`open_camera` and optional `open_archive`. This keeps the repository honest
until a real local executor exists.

### Decision: Camera-stream metadata stays summary-first

Ordinary reads expose only the non-secret summary and action metadata needed
for operator navigation. Provider-specific raw media payloads remain redacted.

### Decision: Same-device playback stays fail-closed

The repository does not claim local media playback until a later change adds a
family-specific executor and verification evidence.
