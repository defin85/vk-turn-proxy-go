# Change: [81] Add flow-6 WB Stream WebRTC datachannel candidate

## Why

`add-80-flow-6-wb-stream-same-device-attach-path` defines the truthful WB
same-device boundary: a room-authenticated attach bootstrap exists, but WB
still must not be flattened into `generic_turn`.

What remains missing is the next explicit hypothesis: which carrier should the
repository try first on top of that attach surface.
The strongest current candidate is the already-planned generic tuple from
`add-24-flow-5-research-webrtc-datachannel-runtime-path`:

- `access_method=webrtc_call_attach`
- `carrier_family=webrtc_datachannel`
- `engine_family=custom_packet_overlay`
- `remote_endpoint_family=webrtc_call_endpoint`

This still must remain experimental.
The live WB evidence proves attach bootstrap and relay allocation, but it does
not yet prove repo-owned payload over a datachannel.
It also does not prove that `webrtc_datachannel` is the only plausible WB
carrier family. The new `olcrtc` evidence shows a sibling provider-specific
room data plane around LiveKit room data packets, so this change must stay
non-exclusive even while choosing the first explicit generic candidate.

## Sequence

- Order: `81`
- Depends on:
  `add-24-flow-5-research-webrtc-datachannel-runtime-path`,
  `add-80-flow-6-wb-stream-same-device-attach-path`
- Unblocks: a WB-specific same-device candidate path that can later be
  implemented and verified without pretending that TURN is already solved

## What Changes

- Extend `wb-stream-attach-runtime` so the first explicit generic WB
  same-device candidate tuple is the
  `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay` path,
  without excluding a later sibling provider-specific room-data-plane
  candidate.
- Extend `webrtc-datachannel-carrier` so WB startup uses the
  room-authenticated attach bootstrap and provider-owned call endpoint
  discovered in live research rather than a guessed generic room-open flow,
  while keeping the documented tuple distinct from any future LiveKit
  room-data-plane path.
- Extend `client-control-plane` so hosts can advertise this WB-specific
  candidate as experimental and fail closed when attach bootstrap exists but
  payload-ready datachannel runtime is not verified.
- Keep the path non-default until repo-owned payload evidence proves that the
  WB call endpoint can carry the documented datachannel overlay.

## Impact

- Affected specs:
  `wb-stream-attach-runtime`,
  `webrtc-datachannel-carrier`,
  `client-control-plane`
- Affected code:
  future WB attach/runtime packages,
  `pkg/clientcontrol`,
  host execution planning,
  verification/docs evidence,
  desktop/mobile shell consumers

## Assumptions

- The first realistic WB same-device candidate is still conference attach, not
  transport-ready TURN.
- The first explicit generic carrier candidate is `webrtc_datachannel`, but WB
  may still require a narrower provider-specific room-data-plane carrier such
  as LiveKit data packets.
- Support claims must stay evidence-gated until repo-owned payload proof
  exists for whichever carrier candidate is being documented.
