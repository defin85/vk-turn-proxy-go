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

That approval must cover the committed same-session browser-observed contour
for this flow and must not be constrained only to browser-owned replay-request
continuations. The owned-browser contract is the app-owned browser session
boundary, not one specific continuation transport.

Desktop or other shells can keep the current invite-first behavior until there
is separate evidence for authenticated `calls.vk.com` handling there.

### Decision: Remembered owned-browser sign-in is a parallel convenience, not a prerequisite

The authenticated `calls.vk.com` contour must remain implementable and
supportable with a fresh app-owned browser session.

The separate `add-32-mobile-owned-browser-login-memory` change shares the same
browser-state boundary but is not a hard dependency for this change. If
remembered sign-in exists, it may accelerate the supported flow; if it does
not, the authenticated hosted-call path must still work from signed-out
embedded state.

### Decision: Explicit reset clears owned-browser site data, not shell state

The authenticated `calls.vk.com` flow needs one explicit reset or forget path
for the app-owned browser session.

That reset should clear only the app-owned browser session data required for
owned-browser continuation, including:

- cookies
- WebView storage used by the remembered sign-in session

It must not wipe:

- saved profiles
- managed providers
- drafts
- ordinary shell preferences
- diagnostics history

### Decision: Keep authenticated compatibility fixtures in the existing flat VK fixture family

The current VK compatibility tooling and runtime references already target the
flat `test/compatibility/vk/fixtures/` layout.

The authenticated hosted-call contour should therefore stay in that existing
fixture root, but use a distinct scenario-name family such as
`vk_call_authenticated_*` so replay tooling, runtime references, and review
diffs can distinguish it cleanly from the invite-first contour without
introducing a second ad hoc directory scheme.

### Decision: Authenticated compatibility evidence must stay schema-distinct from invite-first fixtures

The authenticated hosted-call contour cannot be kept separate by file naming
alone.

The compatibility contract should also distinguish the authenticated contour at
the schema and README level so replay tooling can tell:

- authenticated `calls.vk.com` start evidence
- invite-first `vk.com/call/join/...` evidence

apart without guessing from fixture filenames.

That means the authenticated fixture family must not be forced through an
invite-only input contract such as mandatory normalized join-token fields when
the committed authenticated contour starts from the canonical
`https://calls.vk.com/` root link.

## Risks / Trade-offs

- VK can change the authenticated hosted-call response shape or gate it behind
  additional anti-bot or account-state checks; the resolver must therefore stay
  fail-closed.
- The current mobile capture path depends on document-start JavaScript plus
  browser-observed POST responses from the owned browser session; if VK moves
  the committed contour behind non-observable transports or non-matching
  origins, the product must fail closed and refresh the compatibility evidence
  before widening support claims.
- A remembered mobile owned-browser sign-in can change the visual first page at
  `calls.vk.com`; shell UX should define the supported start path in terms of
  the app-owned browser session, not in terms of one hard-coded first screen.
- The authenticated flow is account-backed, so artifact sanitization must keep
  account identifiers, session keys, and provider join links redacted outside
  explicit allowed surfaces.

## Migration Plan

- Keep existing legacy invite normalization and tests untouched while adding
  the authenticated branch.
- Add authenticated contour compatibility fixtures and replay tests before
  widening UI claims.
- Expose the additive `calls.vk.com` path only where the mobile owned-browser
  path is already approved.

## Validation Plan

- `openspec validate add-37-vk-calls-authenticated-owned-browser-flow --strict --no-interactive`
- targeted Go tests for `internal/provider/vk`, `internal/androidembeddedhost`,
  `pkg/clientcontrol`, and `cmd/probe`
- compatibility replay checks for `test/compatibility/vk`
- `cd mobile/gui_shell && flutter analyze && flutter test`
- live Android owned-browser harness run from `https://calls.vk.com/` to
  transport-ready capture
