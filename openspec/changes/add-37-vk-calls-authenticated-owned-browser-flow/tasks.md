## 1. VK Provider Contract
- [x] 1.1 Extend VK input normalization so the supported
  `https://calls.vk.com/` start link is accepted as an additional VK input
  while preserving the existing `vk.com/call/join/<token>` behavior.
- [x] 1.2 Add an explicit browser-observed contour for the authenticated VK
  hosted-call path using `auth.anonymLogin` bootstrap plus
  `vchat.startConversation(createJoinLink=true)` transport-ready payloads.
- [x] 1.3 Keep the legacy invite/guest contour unchanged and fail closed when
  the authenticated contour does not yield transport-ready data.
- [x] 1.4 Keep replayable authenticated-contour compatibility evidence separate
      from the legacy invite-first VK contour instead of relying only on live
      harness evidence.

## 2. Mobile Owned-Browser Path
- [x] 2.1 Add the mobile app-owned browser start path for
  `https://calls.vk.com/` so the operator can authenticate and reach the
  provider-owned hosted-call UI inside one owned-browser session.
- [x] 2.2 Preserve app-owned browser state only inside the app sandbox, keep
  reset or forget semantics explicit, clear owned-browser cookies plus site
  storage required for remembered auth, and do not import the user's external
  browser profile state or wipe unrelated shell state.
- [x] 2.3 Keep operator UX explicit that authenticated `calls.vk.com` support
  is additive and does not remove the existing `vk.com/call/join/...` path.
- [x] 2.4 Update the mobile owned-browser approval and control-plane
      challenge-metadata path so the authenticated contour can continue from
      same-session browser-observed evidence and is not limited to
      browser-owned replay requests.
- [x] 2.5 Keep the authenticated hosted-call path valid from a fresh app-owned
      browser session even when remembered embedded sign-in from change `32`
      is unavailable.

## 3. Evidence and Coverage
- [x] 3.1 Add sanitized compatibility fixtures for the authenticated VK
  contour, including `auth.anonymLogin` bootstrap data and
  `vchat.startConversation(createJoinLink=true)` responses with `turn_server`.
- [x] 3.1a Keep those authenticated fixtures in
      `test/compatibility/vk/fixtures/` with a distinct scenario family such
      as `vk_call_authenticated_*` instead of mixing them into the invite-first
      naming pattern.
- [x] 3.1b Update `test/compatibility/vk/fixture.schema.json` and
      `test/compatibility/vk/README.md` so the authenticated fixture family is
      distinguished by contract metadata and input family, not by filename
      alone, and is not forced through invite-only normalized join-token input
      rules.
- [x] 3.2 Extend provider and host tests so both the legacy invite path and the
  new authenticated `calls.vk.com` path remain covered, including replayable
  compatibility checks.
- [x] 3.3 Add mobile shell coverage for the owned-browser authenticated flow,
  including same-session navigation and explicit failure when transport-ready
  data is missing.

## 4. Validation
- [x] 4.1 Run `go test ./internal/provider/vk ./internal/androidembeddedhost ./pkg/clientcontrol ./cmd/probe`.
- [x] 4.2 Run `go test ./test/compatibility/vk/...`.
- [x] 4.3 Run `cd mobile/gui_shell && flutter analyze && flutter test`.
- [x] 4.4 Run a live Android Dart MCP owned-browser harness pass from
  `https://calls.vk.com/` through authentication and hosted-call creation to
  verify transport-ready observed data is still captured.
- [x] 4.5 Run `openspec validate add-37-vk-calls-authenticated-owned-browser-flow --strict --no-interactive`.
