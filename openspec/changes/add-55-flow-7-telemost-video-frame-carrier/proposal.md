# Change: [55] Add flow-7 Telemost video-frame carrier

## Why
The first credible high-throughput Telemost path is not a TURN-backed handoff
and not the already proposed `webrtc_datachannel` carrier. It is a different
execution family: repo-owned runtime traffic attached to a conference surface
and carried through published video frames.

The repository currently has no contract for that path. Without one, future
implementation would either:

- overload `webrtc_datachannel` with a meaning it does not have
- smuggle provider-specific media attach state through ordinary reads
- or claim a generic "conference mode" without a typed runtime tuple

Flow-7 needs one explicit carrier proposal for the first Telemost-driven
same-device path.

## Sequence
- Order: `55`
- Depends on: `add-22-runtime-execution-planning`,
  `add-53-flow-7-telemost-provider-readiness`,
  `add-54-flow-7-telemost-provider-contract`
- Unblocks: `add-56-flow-7-telemost-release-verification`

## What Changes
- Add a new `webrtc-video-frame-carrier` capability for the first repo-owned
  same-device execution path that rides through conference-published video
  frames.
- Define that path narrowly as:
  `access_method=webrtc_call_attach`,
  `carrier_family=webrtc_video_frames`,
  `engine_family=custom_packet_overlay`,
  `remote_endpoint_family=webrtc_call_endpoint`.
- Extend provider artifact and client control-plane contracts so shells can
  negotiate this path explicitly and hosts can keep attach state redacted.
- Keep the path experimental, non-default, and fail-closed until repo-owned
  release verification proves payload traffic over the documented carrier.

## Impact
- Affected specs: `webrtc-video-frame-carrier` (new),
  `provider-runtime-artifacts`, `client-control-plane`
- Affected code: future Telemost attach/runtime packages, `pkg/clientcontrol`,
  provider artifact modeling, desktop/mobile shell consumers, verification docs

## Assumptions
- The first reviewed same-device path uses conference attach semantics rather
  than transport-ready TURN credentials.
- The first carrier family is video-frame-based and must not be conflated with
  `webrtc_datachannel`.
- The first local engine can stay on the repo-owned `custom_packet_overlay`
  family.
