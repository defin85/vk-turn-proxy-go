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

## Current Evidence Snapshot

- As of May 8, 2026, `smarthome` remains the strongest researched
  `camera_stream` candidate for this change.
- Web evidence currently points to a one-sided provider-owned player contour:
  account-bound navigation into `/devices/{id}`, `blob:` playback,
  `srcObject = null`, and media delivery through
  `wss://live-msk2.camera.rt.ru/stream/.../live.mp4`.
- Native evidence currently points to a provider-owned cloud player contour:
  `VCKIT-SESSION`, `VCKIT-STREAM_SPIF`, `spif2-proto` over
  `https://live-msk2.camera.rt.ru/blue7`, and `p2p_mode=false` on both same-LAN
  and mobile-network tests.
- Local camera evidence showed an authenticated RTSP surface on `192.168.0.14`
  but no committed user-owned or host-owned local continuation in the current
  product flow.

## Decisions

### Decision: The first camera-stream action surface is navigation-first

The first committed actions are shell-external navigation targets such as
`open_camera` and optional `open_archive`. This keeps the repository honest
until a real local executor exists.

### Decision: Camera-stream metadata stays summary-first

Ordinary reads expose only the non-secret summary and action metadata needed
for operator navigation. Provider-specific raw media payloads remain redacted.

### Decision: Provider-owned player transport evidence does not promote local execution

Concrete player transport evidence such as websocket `fMP4`, native
`spif2-proto`, or hidden authenticated RTSP is useful for future
provider-specific executor work, but it does not change the committed first
action surface in this change. Until a later follow-up proves and ships a
family-specific executor, the contract stays navigation-first and fail-closed.

### Decision: Same-device playback stays fail-closed

The repository does not claim local media playback until a later change adds a
family-specific executor and verification evidence.

### Decision: Follow-up research targets provider-selected local or P2P mode

Further research for camera-style providers should focus on whether the
provider itself ever advertises a typed local or P2P continuation such as
`p2p_mode=true` when the cloud media contour is unavailable. That work belongs
in provider-specific follow-ups rather than in the generic `camera_stream`
action surface.
