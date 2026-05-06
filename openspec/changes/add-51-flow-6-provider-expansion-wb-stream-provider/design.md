## Context

`WB Stream` is the first concrete conference-style provider candidate beyond
VK. The target service is the public Wildberries/RWB Stream surface at
`https://stream.wb.ru/`.

The public product material describes WB Stream as a web and native-app service
for meetings, video and audio conferences, broadcasts, chat, screen sharing,
recording, planning, and recurring meeting links. The user agreement describes
guest entry and authorization by nickname or phone, and notes that phone-backed
authorization may use or create Wildberries account state.

The repository needs one provider-specific contract that can sit on top of the
generic `conference_room` family without turning the shells back into
provider-name-specific workflow code.

## Goals

- Define the first provider-specific contract for `wb-stream` room links rooted
  at `https://stream.wb.ru/`.
- Keep the output mapped to `conference_room` plus the committed action
  surface.
- Keep browser, auth, anti-bot, and legal/commercial posture explicit.
- Make the first slice useful as an operator-facing external open-room flow
  before any same-device media execution exists.

## Non-Goals

- Add local conference execution.
- Flatten WB-specific room access into `generic_turn`.
- Claim embedded-browser support, headless scraping, or direct media/signaling
  attach unless a later provider-approved change does so explicitly.
- Extract provider tokens, room secrets, chat tokens, recording URLs, or WebRTC
  signaling payloads from ordinary WB Stream pages.
- Automate WB account creation or bypass provider anti-bot controls.

## Decisions

### Decision: WB resolution ends in `conference_room`

Successful WB resolution maps to the committed `conference_room` artifact
family and its action surface rather than to tunnel semantics.

The first successful resolved state is intentionally narrow: a normalized
non-secret room URL plus optional display summary and an `open_room` action.
It is not evidence that RelayDock can execute, proxy, record, or inspect WB
Stream media locally.

### Decision: Auth and browser posture stay explicit

The descriptor must state the committed entry posture for WB as
`guest_or_account` plus an external-browser/app handoff. Shells must not guess
whether embedded WebView, phone-code login, corporate Wildberries account state,
or guest entry is valid from the provider name alone.

Direct unauthenticated HTTP access can return a WBAAS anti-bot challenge page.
That is a provider boundary, not a parser target. A future resolver may use
operator-provided URLs, provider-approved browser observation, or explicit
artifact service input, but it must not rely on hidden API guesses or
headless anti-bot bypass.

### Decision: Ordinary reads stay redacted

Room, media, chat, or bootstrap secrets remain redacted in ordinary reads and
only the non-secret action surface is exposed.

### Decision: First slice is external open-room, not same-device execution

The first WB Stream slice should ship only after the host and shells can expose
a typed `conference_room` artifact with `open_room` action. Same-device media
attach, local WebRTC runtime execution, transport-profile compatibility, and
TURN export remain separate future work.

### Decision: Commercial/legal posture is explicit

The public agreement describes ordinary use terms and states that commercial use
outside the agreement requires separate permission from RWB. RelayDock must not
represent WB Stream automation, account-backed provisioning, recording export,
or commercial redistribution as supported unless a later change records the
permission and evidence boundary explicitly.

## Options Considered

- Option A: Model WB Stream as `generic_turn`.
  Rejected. Public material describes a conference product, not a TURN handoff,
  and the current provider-runtime contract already distinguishes
  `conference_room` from `generic_turn`.
- Option B: Build a headless resolver around page/API scraping.
  Rejected for the first slice. The web entrypoint can present WBAAS anti-bot
  challenge behavior, and no public API contract is committed in the repository.
- Option C: Start with external `open_room`.
  Chosen. It gives a truthful provider integration surface, matches existing
  `conference_room` actions, and preserves fail-closed behavior for unsupported
  same-device execution.

## Risks / Trade-offs

- Risk: WB Stream URL shapes or auth requirements drift.
  Mitigation: keep URL acceptance narrow, fixture-backed, and fail-closed.
- Risk: operators expect RelayDock to run WB media locally after seeing the
  provider in the catalog.
  Mitigation: descriptor and shell copy must say external open-room only until a
  separate executor exists.
- Risk: provider-owned anti-bot or account policies make automation fragile or
  impermissible.
  Mitigation: avoid headless scraping and require live evidence before promotion.
- Risk: ordinary logs or diagnostics leak room URLs with passwords or tokens.
  Mitigation: treat room URLs as sensitive unless proven public, redact token or
  password-bearing parts, and keep export explicit.
