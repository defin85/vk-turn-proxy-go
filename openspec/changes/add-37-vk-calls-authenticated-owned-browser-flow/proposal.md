# Change: [37] Add authenticated VK Calls owned-browser flow

## Why
The currently specified VK product path is invite-first: the operator pastes a
standard `https://vk.com/call/join/...` link and the provider resolves that
guest or preview flow into transport-ready TURN credentials.

Live Android owned-browser evidence now shows a second real VK contour:
starting from `https://calls.vk.com/`, authenticating inside the app-owned
`WebView`, and creating a hosted call in that same session yields
provider-observed `auth.anonymLogin` bootstrap data plus
`vchat.startConversation(createJoinLink=true)` responses containing
`turn_server`, `stun_server`, join-link, and websocket endpoints.

That makes `calls.vk.com` a viable additional VK session-start path, but it is
not the same contour as the existing invite-first workflow. The product needs
an explicit additive change that preserves the old `vk.com/call/join/...`
behavior instead of silently replacing it.

## Sequence
- Order: `37`
- Depends on: `add-29-mobile-vpn-product-shell`
- Unblocks: authenticated VK session start from `calls.vk.com` on mobile
  app-owned browser surfaces without regressing legacy invite-first VK input

## What Changes
- Add an authenticated VK Calls flow that accepts the supported
  `https://calls.vk.com/` start link as an additional VK session input on the
  approved mobile app-owned browser path.
- Keep the existing `https://vk.com/call/join/...` invite-first workflow
  supported and unchanged as a first-class VK input path.
- Define a distinct browser-observed provider contour for the authenticated
  hosted-call path based on `auth.anonymLogin` bootstrap plus
  `vchat.startConversation(createJoinLink=true)` transport data, rather than
  forcing that flow through the legacy invite/guest contour.
- Scope the first release to that authenticated hosted-call creation contour
  only and keep other authenticated post-login branches, including reopen of an
  existing call, outside the supported contract until separate evidence exists.
- Require the mobile owned-browser approval path to cover same-session
  browser-observed continuation evidence for that committed contour instead of
  assuming only browser-owned replay requests can drive embedded continuation.
- Add sanitized replayable compatibility evidence for the authenticated
  hosted-call contour and keep it distinct from the legacy invite-first VK
  contour.
- Require fail-closed handling when the authenticated embedded browser flow
  stops before transport-ready data or only yields account/bootstrap state.

## Impact
- Affected specs: `vk-authenticated-call-workflow`,
  `vk-invite-user-workflow`, `mobile-webview-provider-continuation`,
  `client-control-plane`, `vk-call-debug-contour`
- Affected code:
  - `internal/provider/vk`
  - `internal/androidembeddedhost`
  - `pkg/clientcontrol`
  - `cmd/probe`
  - `mobile/gui_shell`
  - `test/compatibility/vk`
  - VK provider tests, owned-browser harness coverage, and related docs
