# Change: Add browser-assisted VK resolution

## Why
On April 4, 2026, live probe attempts against two different VK invite links showed that `calls.getAnonymousToken` still returns `Captcha needed` even after the operator completes the browser challenge and confirms continuation in the CLI.
This proves the current operator-assisted retry flow is not enough for live VK resolution: stage 2 appears to depend on browser session state that the plain HTTP client does not carry forward.

## What Changes
- Add a browser-assisted VK provider mode that resolves captcha-gated invites through a controlled browser session owned by the operator.
- Keep the existing non-interactive and plain interactive retry paths fail-closed when browser-backed continuation is unavailable.
- Let `cmd/probe` and `cmd/tunnel-client` opt into browser-assisted provider resolution before any transport startup.
- Add compatibility fixtures and manual verification guidance for browser-assisted VK resolution outcomes.

## Impact
- Affected specs: `vk-call-debug-contour`, `tunnel-client-runtime`
- Affected code: `internal/provider/vk`, `cmd/probe`, `cmd/tunnel-client`, provider/browser session helpers, compatibility tests and docs
