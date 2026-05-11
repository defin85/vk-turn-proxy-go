## Context

`add-51-flow-6-provider-expansion-wb-stream-provider` intentionally made WB
support truthful and narrow: validate supported `https://stream.wb.ru/...`
room links, resolve them to `conference_room`, and expose only shell-external
`open_room`.

Live research on May 6, 2026 found a stronger provider-owned runtime surface:

- a room-authenticated `connection-details` request under the active WB
  browser session
- provider-specific prerequisites:
  `Authorization: Bearer <accessToken>`,
  `deviceType=PARTICIPANT_DEVICE_TYPE_WEB_DESKTOP`,
  `displayName`
- a bootstrap response containing `serverUrl`, `roomToken`, and
  `rtcConfig.iceServers`

The same research also found that this still is not enough to call WB a TURN
provider:

- relay-only ICE gathering succeeded against the returned TURN endpoints
- but a local TURN-only peer test failed even though a host-only control test
  succeeded

That evidence points to a different architectural truth: WB same-device work
must start from a room-authenticated attach bootstrap and a provider-owned call
endpoint, not from a guessed `generic_turn` interpretation.

Comparative code evidence from `/home/egor/code/olcrtc` sharpens the same
point:

- a real `wbstream` provider resolves WB room tokens under authenticated room
  context
- it connects to `wss://wbstream01-el.wb.ru:7880`
- it exchanges payload through LiveKit room data packets via
  `PublishDataPacket`

That is still evidence for a provider-owned attach surface, but not a reason
to collapse the boundary into either `generic_turn` or an already-chosen
generic `webrtc_datachannel` carrier.

## Goals

- Define one explicit WB same-device attach boundary that starts from
  provider-authenticated room state.
- Keep attach/session/bootstrap secrets inside the host boundary.
- Keep `open_room` and future same-device execution as separate surfaces.
- Keep the attach boundary carrier-neutral so later changes can document either
  a generic datachannel tuple or a narrower WB-specific room-data-plane
  carrier.
- Require live payload evidence against the provider-owned call endpoint before
  any support claim.

## Non-Goals

- Claiming that WB Stream is a `generic_turn` provider
- Claiming that provider-issued TURN lines already prove a packaged VPN path
- Bypassing anti-bot or guessing hidden APIs from unauthenticated pages
- Serializing bearer tokens, room tokens, or raw attach blobs through ordinary
  shell-facing reads
- Pre-choosing the final non-TURN carrier family before live payload evidence

## Decisions

### Decision: WB same-device work starts from room-authenticated attach bootstrap

The first same-device WB slice starts from the provider-owned
`connection-details` bootstrap and whatever room-authenticated attach state is
required to consume it safely.
It does not start from `turn_credentials`, because the live evidence does not
prove that WB-issued ICE/TURN lines behave like a transport-ready artifact.

### Decision: `connection-details` is prerequisite evidence, not readiness

The discovered `serverUrl`, `roomToken`, and ICE/TURN configuration prove that
WB exposes a room-authenticated attach contour.
They do not yet prove that RelayDock can move repo-owned payload through that
contour.
Relay allocation, ICE gathering, or a parsed bootstrap response remain
intermediate evidence only.

### Decision: Ordinary reads stay redacted and host-owned

WB bearer tokens, room tokens, display-bound attach inputs, and any later
provider-specific offers, session IDs, or signaling state remain inside the
host boundary.
Ordinary resolution reads and diagnostics may expose typed readiness/failure
metadata, but not raw attach material.

### Decision: `open_room` remains valid and separate

The already-committed WB room-open flow remains truthful and useful on its own.
A future same-device path must be advertised explicitly as an additional
surface, not smuggled in as if `open_room` already implied local execution.

### Decision: Carrier choice stays follow-on until payload evidence exists

The final same-device tuple may later become
`webrtc_call_attach + webrtc_datachannel + custom_packet_overlay` or another
documented non-TURN path.
This change does not claim that outcome in advance.
Its job is to create the truthful provider-specific attach boundary and the
evidence gate that any later carrier proposal must satisfy.

### Decision: The WB attach boundary stays neutral between generic and provider-specific carriers

The attach boundary should not force later work into one carrier interpretation.
If future evidence supports a generic `webrtc_datachannel` tuple, that can sit
on top of this boundary.
If future evidence instead supports a narrower provider-specific room data
plane such as LiveKit room data packets, that can also sit on top of this
boundary.
The boundary itself remains the same: room-authenticated WB attach/bootstrap,
host-owned secrets, provider-owned call endpoint, and fail-closed readiness.

## Risks / Trade-offs

- WB may require provider-specific signaling or room semantics that do not map
  cleanly onto the first planned repo-owned carrier.
- WB may end up needing a provider-specific room-data-plane carrier even if a
  generic datachannel candidate remains worth testing.
- Browser/session prerequisites may drift, including anti-bot or account
  posture changes.
- If attach bootstrap is underspecified, later work may leak secrets into
  ordinary host or shell state.
- Deferring the carrier decision adds an extra proposal step, but avoids
  overstating TURN or datachannel readiness without proof.

## Validation Plan

- Add a new `wb-stream-attach-runtime` capability spec for the provider-owned
  attach boundary.
- Extend `provider-runtime-artifacts` and `client-control-plane` so WB attach
  evidence fails closed instead of masquerading as TURN or local readiness.
- Keep the documented boundary neutral with respect to later generic versus
  provider-specific carrier proposals.
- Keep any future support claim gated on repo-owned payload evidence against the
  provider-owned call endpoint.
- `openspec validate add-80-flow-6-wb-stream-same-device-attach-path --strict --no-interactive`
