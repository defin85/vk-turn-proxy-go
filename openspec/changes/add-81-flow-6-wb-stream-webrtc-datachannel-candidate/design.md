## Context

`add-24-flow-5-research-webrtc-datachannel-runtime-path` already defined the
generic experimental tuple
`webrtc_call_attach + webrtc_datachannel + custom_packet_overlay`.
`add-80-flow-6-wb-stream-same-device-attach-path` then established that WB has
an attach bootstrap contour, but not an honest `generic_turn` one.

The next question is narrower than both earlier changes:

- not "does a generic datachannel path exist in theory?"
- not "does WB expose any attach bootstrap?"
- but "is the first WB same-device candidate specifically the generic
  datachannel tuple?"

Live evidence from May 6, 2026 supports that as the best next hypothesis:

- WB room state yields `connection-details`, `serverUrl`, `roomToken`, and
  ICE/TURN lines under authenticated room context
- relay allocation works against WB-issued TURN lines
- TURN-only local peer tests still fail, so the repository should not keep
  pushing WB toward `turn_credentials`

Additional comparative evidence from `/home/egor/code/olcrtc` matters too:

- a real `wbstream` provider resolves WB room tokens under authenticated room
  context
- it connects to `wss://wbstream01-el.wb.ru:7880`
- it exchanges payload through LiveKit room data packets via
  `PublishDataPacket`, not through a proven generic TURN export

That keeps a conference-attached datachannel path as the most honest first
generic candidate to specify, while also showing that WB may later need a
provider-specific room-data-plane sibling path.

## Goals

- Bind the already-planned generic datachannel tuple to the WB attach contour.
- Keep the candidate explicit, experimental, and non-default.
- Keep the change non-exclusive so a later provider-specific WB room-data-plane
  candidate can coexist with the documented tuple.
- Preserve the host-owned redaction boundary for WB attach/bootstrap secrets.
- Require payload-ready evidence over the provider-owned call endpoint before
  any runtime support claim.

## Non-Goals

- Claiming that the WB datachannel path is already implemented
- Claiming that channel open, room join, or relay allocation alone imply
  support
- Renaming WB attach bootstrap as `turn_credentials`
- Broadening the change into a generic contract for every conference provider

## Decisions

### Decision: First explicit generic WB candidate reuses the generic datachannel tuple

The repository already has one explicit non-TURN candidate tuple in planning:
`webrtc_call_attach + webrtc_datachannel + custom_packet_overlay`.
WB should reuse that tuple for its first same-device candidate rather than
inventing a second competing datachannel naming scheme.
This choice is deliberately scoped to the first explicit generic candidate. It
does not mean that every future WB same-device carrier must be expressed as
`webrtc_datachannel`.

### Decision: The datachannel candidate does not consume the whole WB attach surface

`olcrtc` shows a provider-specific WB data plane built around LiveKit room data
packets. The repository should therefore avoid wording that would make
`add-81` sound exclusive. This change documents one candidate tuple on top of
the WB attach surface, while leaving room for a later sibling change that
models a narrower provider-specific room-data-plane carrier.

### Decision: WB startup uses provider-authenticated attach state, not room-open alone

For WB, the datachannel candidate must start from the room-authenticated
attach/bootstrap contour documented by `add-80`.
An ordinary `open_room` action or naked room URL is not enough to truthfully
claim the candidate path.

### Decision: Relay allocation and channel-open are both intermediate evidence

The evidence bar stays strict.
WB-issued relay allocation is useful but not sufficient.
Likewise, if a later runtime can open a datachannel but cannot move repo-owned
payload, that still is not support.

### Decision: Experimental status remains provider-visible

Hosts and shells should be able to expose that WB has a candidate attach tuple
without pretending that it is packaged, default, or support-ready.
The control plane should therefore report this path explicitly as experimental
until the verification bar is met.

## Risks / Trade-offs

- The final WB carrier may still turn out to be something other than
  `webrtc_datachannel`.
- WB signaling or room semantics may require provider-specific attach behavior
  that keeps implementation narrower than the generic `add-24` model.
- The final supported WB carrier may be closer to LiveKit room data packets
  than to a generic negotiated datachannel path.
- If the proposal overstates readiness, users may confuse a candidate path with
  a shipped one.

## Validation Plan

- Modify `wb-stream-attach-runtime` so the first explicit generic WB candidate
  is the generic datachannel tuple without excluding a later provider-specific
  room-data-plane sibling.
- Modify `webrtc-datachannel-carrier` so the generic tuple stays compatible with
  room-authenticated WB bootstrap and provider-owned call endpoints while
  remaining non-exclusive with respect to other documented WB carrier
  candidates.
- Modify `client-control-plane` so hosts fail closed when WB attach bootstrap
  exists but payload-ready datachannel support is still unverified.
- `openspec validate add-81-flow-6-wb-stream-webrtc-datachannel-candidate --strict --no-interactive`
