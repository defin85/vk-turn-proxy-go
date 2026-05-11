# Change: [80] Add flow-6 WB Stream same-device attach path

## Why

`add-51-flow-6-provider-expansion-wb-stream-provider` intentionally stopped at
`conference_room + open_room`.
Live browser-observed WB research on May 6, 2026 found a room-authenticated
attach bootstrap behind the provider session:
`GET /api-room-manager/v2/room/{roomId}/connection-details` with
`deviceType=PARTICIPANT_DEVICE_TYPE_WEB_DESKTOP`, a provider bearer token,
`serverUrl`, `roomToken`, and `rtcConfig.iceServers`.

That same research also showed that bare TURN evidence is not enough for an
honest support claim. Relay allocation succeeded, but a local TURN-only peer
test still failed. The next truthful WB slice is therefore a separate
same-device attach path, not a reinterpretation of WB Stream as
`generic_turn`.
Comparative evidence from `/home/egor/code/olcrtc` also suggests that the WB
attach surface may feed a provider-specific room data plane around LiveKit
room data packets, not only a future generic `webrtc_datachannel` candidate.
This change therefore must stay carrier-neutral.

## Sequence

- Order: `80`
- Depends on:
  `add-49-flow-6-provider-expansion-conference-room-actions`,
  `add-51-flow-6-provider-expansion-wb-stream-provider`
- Unblocks: future WB-specific same-device runtime implementation and live
  verification without overloading the TURN path

## What Changes

- Add a new `wb-stream-attach-runtime` capability that defines the
  room-authenticated WB attach bootstrap and its support gate.
- Extend `provider-runtime-artifacts` so provider-issued ICE/TURN lines inside
  a conference attach bootstrap do not masquerade as `turn_credentials`.
- Extend `client-control-plane` so hosts fail closed when WB attach bootstrap
  exists but no verified same-device execution tuple is packaged.
- Keep the first WB attach slice experimental, non-default, and redacted until
  repo-owned payload evidence exists against the provider-owned call endpoint.
- Keep the attach boundary carrier-neutral so later changes may document either
  a generic `webrtc_datachannel` tuple or a narrower WB-specific room-data-
  plane candidate without rewriting the boundary itself.

## Impact

- Affected specs:
  `wb-stream-attach-runtime` (new),
  `provider-runtime-artifacts`,
  `client-control-plane`
- Affected code:
  future WB attach bootstrap/state handling,
  `pkg/clientcontrol`,
  host runtime planning,
  desktop/mobile shell consumers,
  live verification/docs evidence

## Assumptions

- Approved WB same-device work starts from provider-authenticated room attach
  state, not from anonymous TURN reuse.
- The final carrier family may be `webrtc_datachannel`, a provider-specific
  room-data-plane path, or another non-TURN path, but this change does not
  pre-claim that result.
