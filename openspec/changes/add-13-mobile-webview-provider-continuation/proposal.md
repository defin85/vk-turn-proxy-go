# Change: [13] Add optional mobile WebView provider continuation

## Why
The recommended mobile path should stay platform-native browser handoff with safe auto-resume hints, but that path still leaves one structural limit:
the app does not fully own the browser session used for provider continuation.

For providers whose continuation state is tightly bound to a browser session, a system-browser-only path may never provide full control over completion timing, session continuity, or observation.
An optional owned WebView path is the most direct way to explore full in-app control on mobile without redefining the default browser-handoff contract for every provider.

## Sequence
- Order: `13`
- Depends on: `add-03-mobile-gui-shell`
- Unblocks: `add-05-platform-tunnel-integrations`

## What Changes
- Define an optional in-app WebView continuation mode for approved mobile providers that need app-owned web session control.
- Keep the default mobile path system-browser-oriented; the WebView path is an explicit provider- and policy-gated mode, not the baseline mobile workflow.
- Require owned web-session continuity, explicit in-app challenge presentation, and fail-closed behavior when embedded continuation is unsupported or cannot be validated.
- Define how the mobile shell selects between system browser handoff and in-app owned WebView continuation through typed challenge metadata rather than provider-specific UI heuristics.

## Impact
- Affected specs: `mobile-webview-provider-continuation`, `mobile-gui-client`
- Affected code: future mobile Flutter shell, Android WebView and iOS WKWebView bridge code, provider continuation policy, app-owned cookie/session sandboxing, mobile challenge docs
