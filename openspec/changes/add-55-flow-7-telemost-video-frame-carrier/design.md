## Context

`add-22-runtime-execution-planning` created room for non-TURN same-device
execution, and `add-24` proposed one experimental path through
`webrtc_datachannel`.

Telemost points to a different carrier family. The strongest currently known
candidate path is an attachable conference surface whose runtime traffic is
carried through published video frames, not through TURN-backed transport
credentials and not through a WebRTC datachannel.

That needs its own contract.

## Goals

- Define one explicit repo-owned video-frame carrier tuple.
- Keep attach and bootstrap state host-owned and redacted.
- Keep the path experimental until real payload verification exists.

## Non-Goals

- Claim that every conference provider supports a video-frame carrier.
- Treat room join or track publish alone as runtime readiness.
- Replace TURN-backed or datachannel-backed planning.

## Decisions

### Decision: The first Telemost-driven carrier is its own execution family

This path should not be described as TURN-backed and should not reuse
`webrtc_datachannel` naming. It is a distinct carrier family:
`webrtc_video_frames`.

### Decision: The local engine stays on `custom_packet_overlay`

The repository already owns `custom_packet_overlay` as the first packet engine.
The new work should add a different carrier, not a second local packet engine
at the same time.

### Decision: Attach state stays inside the host boundary

A usable video-frame path may require room-scoped attach or publish state.
That state belongs inside the host boundary. Ordinary reads and shell state
should expose only typed plan and failure metadata.

### Decision: Ready state requires payload over the documented carrier

Joining a room, attaching to signaling, or keeping a video track alive is not
enough. The evidence bar for support claims must require actual overlay payload
traffic over the documented video-frame carrier.
