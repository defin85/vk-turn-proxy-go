## Context

`smarthome` is the first concrete camera-style provider candidate. The
repository needs one provider-specific contract that can sit on top of the
generic `camera_stream` family without turning the shells back into
provider-name-specific workflow code.

## Goals

- Define the first provider-specific contract for `smarthome`.
- Keep the output mapped to `camera_stream` plus the committed action surface.
- Keep account and device posture explicit.

## Non-Goals

- Add local media playback.
- Flatten camera/device access into `conference_room` or `generic_turn`.
- Claim tunnel or conference semantics for camera artifacts.

## Decisions

### Decision: Smarthome resolution ends in `camera_stream`

Successful `smarthome` resolution maps to the committed `camera_stream`
artifact family and its action surface rather than to tunnel or conference
semantics.

### Decision: Account or device posture stays explicit

The descriptor must state the committed account and device posture for
`smarthome` rather than leaving shells to infer it from provider-name
heuristics.

### Decision: Ordinary reads stay redacted

Player, stream, archive, or bootstrap secrets remain redacted in ordinary
reads and only the non-secret action surface is exposed.
