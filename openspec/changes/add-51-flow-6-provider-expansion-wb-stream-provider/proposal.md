# Change: [51] Add flow-6 provider expansion for stream.wb.ru

## Why
The repository already has the generic contract needed to describe
conference-style provider results, but it still lacks one provider-specific
contract for the first non-VK conference provider candidate.

`WB Stream` is the Wildberries/RWB conference surface published at
`https://stream.wb.ru/`. Its public product pages describe a web and native-app
service for online meetings, video and audio conferences, broadcasts, chat,
screen sharing, recording, planning, and recurring meeting links. The service
agreement also allows guest or phone-based authorization and ties account-backed
login to Wildberries account state.

That makes `stream.wb.ru` a provider-owned conference surface rather than a
`generic-turn` handoff. Flow-6 therefore needs one explicit provider contract
for how `wb-stream` is advertised, how it enters resolution, and what kind of
artifact it resolves into.

Without that change, future implementation would either guess WB-specific
workflow inside shells or lie by flattening conference access into tunnel
semantics.

## Sequence
- Order: `51`
- Depends on: `add-48-flow-6-provider-expansion-shipping-gates`,
  `add-49-flow-6-provider-expansion-conference-room-actions`
- Unblocks: future WB implementation and release-verification follow-ups

## What Changes
- Add a `wb-stream-provider` capability that defines the descriptor,
  resolution-entry contract, resolution output, and fail-closed behavior for
  the `wb-stream` provider family rooted at `https://stream.wb.ru/`.
- Map successful WB resolution to `conference_room` artifacts plus the
  committed conference-room action surface rather than `generic_turn`.
- Treat the first implementation slice as external-browser/open-room support:
  validate and normalize WB Stream meeting URLs, expose a non-secret
  `conference_room` summary, and let desktop/mobile shells open the room through
  the typed `open_room` action.
- Keep local conference execution, generic-turn export, provider-token
  extraction, headless anti-bot bypass, and implicit embedded-browser support
  out of scope.
- Require redacted ordinary reads and explicit failure behavior for incomplete,
  blocked, or unsupported WB flows.

## Impact
- Affected specs: `wb-stream-provider` (new)
- Affected code: future `internal/provider/wbstream`, `pkg/clientcontrol`,
  desktop/mobile provider entry flows, provider docs, compatibility fixtures

## Assumptions
- `wb-stream` is the stable provider family identifier for the
  `https://stream.wb.ru/` rollout.
- The first slice accepts a WB Stream room or meeting URL as operator input and
  reports guest-or-account auth posture, because the public agreement allows
  guest entry or authorization by nickname/phone while account-backed behavior
  remains provider-owned.
- The first slice uses an external browser/app handoff. Direct unauthenticated
  HTTP fetches can encounter a WBAAS anti-bot challenge, so the implementation
  must not depend on headless scraping or hidden API guesses.
- The first slice does not claim same-device conference execution.

## Evidence Snapshot
- WB Stream product page: `https://promo-digital.wb.ru/`
- WB Stream web entrypoint: `https://stream.wb.ru/`
- WB Stream user agreement: `https://stream.wb.ru/docs/baseUserAgreement.pdf`
- Google Play listing for `com.wbstream_app`
- Apple App Store listing for `WB Stream`
