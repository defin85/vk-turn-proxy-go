## Context

The repository currently has one checked-in VK product contract:

- `vk.com/call/join/<token>` invite intake
- guest or account-assisted browser continuation
- provider contour centered on `calls.getAnonymousToken`,
  `calls.getCallPreview`, `auth.anonymLogin`, and
  `vchat.joinConversationByLink`

That path must stay supported.

Recent live Android owned-browser evidence established a second VK contour that
is materially different:

- start from `https://calls.vk.com/`
- authenticate inside the app-owned `WebView`
- continue in the same owned-browser session until VK opens or creates a call
- observe `calls.okcdn.ru/fb.do` responses for `auth.anonymLogin` and
  `vchat.startConversation(createJoinLink=true)`
- extract transport-ready data directly from the latter response:
  `turn_server`, `stun_server`, join-link, and provider websocket endpoints

That means the product now has two real VK entry workflows, not one:

- legacy invite-first
- authenticated hosted-call start

The key design constraint is additive support.
The authenticated `calls.vk.com` path must not redefine the old invite path as
"deprecated by accident".

## Goals

- Add authenticated `https://calls.vk.com/` as a supported VK session-start
  path on approved mobile app-owned browser surfaces
- Keep `https://vk.com/call/join/...` fully supported
- Parse transport-ready data from the authenticated hosted-call contour
  explicitly instead of pretending it is the legacy invite contour
- Keep the flow provider-owned: authentication and call creation stay inside
  VK-controlled web UI
- Fail closed when the authenticated contour stops before transport-ready data

## Non-Goals

- Removing or downgrading the legacy invite-first VK workflow
- Creating VK calls through undocumented out-of-band API calls outside the
  provider-owned browser UI
- Importing cookies or session data from the user's external browser profile
- Promising desktop parity for `calls.vk.com` in the same change
- Treating every `calls.vk.com` page as supported input before live evidence
  exists for it

## Decisions

### Decision: Keep one VK provider identity and add a second normalized input family

The new flow should stay under the existing `vk` provider identity rather than
introducing a second product-facing provider name.

The operator mental model is still "VK Calls".
What changes is the supported input family and the downstream browser-observed
contour:

- legacy input family: `https://vk.com/call/join/<token>`
- authenticated input family: supported `https://calls.vk.com/` start link

This keeps provider taxonomy stable while allowing the adapter to route into
different resolver branches.

### Decision: Preserve the legacy invite contour as-is

The existing invite-first branch should remain intact.

The authenticated hosted-call branch must not reuse the legacy
`calls.getAnonymousToken -> calls.getCallPreview -> auth.anonymLogin ->
vchat.joinConversationByLink` assumptions, because live evidence does not match
that order.

Instead, the adapter should select the resolver branch from normalized input
family plus observed contour shape.

### Decision: Resolve the authenticated flow from provider-observed hosted-call responses

For the authenticated `calls.vk.com` branch, the committed contour should be:

- bootstrap via `auth.anonymLogin`
- hosted-call creation or reopen via
  `vchat.startConversation(createJoinLink=true)`

The second response is the transport-bearing source of truth because it already
contains:

- `turn_server`
- `stun_server`
- `join_link`
- provider websocket endpoints

The resolver should parse normalized TURN credentials directly from that
provider response rather than reconstructing them from side channels.

### Decision: Keep the product flow provider-owned and browser-mediated

The product should not synthesize hosted-call creation by calling private VK
endpoints outside the owned-browser UI.

Instead, the operator continues inside the approved app-owned browser surface,
and provider resolution consumes only the observed responses from that browser
session.

This keeps the product boundary honest:

- VK account auth stays inside VK UI
- VK hosted-call creation stays inside VK UI
- the app only observes the continuation result and turns it into a typed
  provider artifact

### Decision: Scope the first approved path to mobile owned-browser support

The live proof for this flow currently exists on Android app-owned `WebView`
through the mobile owned-browser harness.

The change should therefore approve `calls.vk.com` first for the mobile
app-owned browser path instead of claiming desktop or generic external-browser
parity immediately.

Desktop or other shells can keep the current invite-first behavior until there
is separate evidence for authenticated `calls.vk.com` handling there.

## Risks / Trade-offs

- VK can change the authenticated hosted-call response shape or gate it behind
  additional anti-bot or account-state checks; the resolver must therefore stay
  fail-closed.
- A remembered mobile owned-browser sign-in can change the visual first page at
  `calls.vk.com`; shell UX should define the supported start path in terms of
  the app-owned browser session, not in terms of one hard-coded first screen.
- The authenticated flow is account-backed, so artifact sanitization must keep
  account identifiers, session keys, and provider join links redacted outside
  explicit allowed surfaces.

## Migration Plan

- Keep existing legacy invite normalization and tests untouched while adding
  the authenticated branch.
- Add authenticated contour fixtures and tests before widening UI claims.
- Expose the additive `calls.vk.com` path only where the mobile owned-browser
  path is already approved.

## Validation Plan

- `openspec validate add-37-vk-calls-authenticated-owned-browser-flow --strict --no-interactive`
- targeted Go tests for `internal/provider/vk`, `internal/androidembeddedhost`,
  and `pkg/clientcontrol`
- `cd mobile/gui_shell && flutter analyze && flutter test`
- live Android owned-browser harness run from `https://calls.vk.com/` to
  transport-ready capture
