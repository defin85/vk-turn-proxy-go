## 1. VK Provider Contract
- [ ] 1.1 Extend VK input normalization so the supported
  `https://calls.vk.com/` start link is accepted as an additional VK input
  while preserving the existing `vk.com/call/join/<token>` behavior.
- [ ] 1.2 Add an explicit browser-observed contour for the authenticated VK
  hosted-call path using `auth.anonymLogin` bootstrap plus
  `vchat.startConversation(createJoinLink=true)` transport-ready payloads.
- [ ] 1.3 Keep the legacy invite/guest contour unchanged and fail closed when
  the authenticated contour does not yield transport-ready data.

## 2. Mobile Owned-Browser Path
- [ ] 2.1 Add the mobile app-owned browser start path for
  `https://calls.vk.com/` so the operator can authenticate and reach the
  provider-owned hosted-call UI inside one owned-browser session.
- [ ] 2.2 Preserve app-owned browser state only inside the app sandbox, keep
  reset or forget semantics explicit, and do not import the user's external
  browser profile state.
- [ ] 2.3 Keep operator UX explicit that authenticated `calls.vk.com` support
  is additive and does not remove the existing `vk.com/call/join/...` path.

## 3. Evidence and Coverage
- [ ] 3.1 Add sanitized fixtures or unit coverage for the authenticated VK
  contour, including `auth.anonymLogin` bootstrap data and
  `vchat.startConversation(createJoinLink=true)` responses with `turn_server`.
- [ ] 3.2 Extend provider and host tests so both the legacy invite path and the
  new authenticated `calls.vk.com` path remain covered.
- [ ] 3.3 Add mobile shell coverage for the owned-browser authenticated flow,
  including same-session navigation and explicit failure when transport-ready
  data is missing.

## 4. Validation
- [ ] 4.1 Run `go test ./internal/provider/vk ./internal/androidembeddedhost ./pkg/clientcontrol`.
- [ ] 4.2 Run `cd mobile/gui_shell && flutter analyze && flutter test`.
- [ ] 4.3 Run a live Android Dart MCP owned-browser harness pass from
  `https://calls.vk.com/` through authentication and hosted-call creation to
  verify transport-ready observed data is still captured.
- [ ] 4.4 Run `openspec validate add-37-vk-calls-authenticated-owned-browser-flow --strict --no-interactive`.
