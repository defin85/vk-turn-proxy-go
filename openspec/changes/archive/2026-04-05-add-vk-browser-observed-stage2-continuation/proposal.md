# Change: Add VK browser-observed stage-2 continuation

## Why
Live HAR capture showed that VK does not resume invite resolution after captcha by simply retrying `calls.getAnonymousToken` from a browser context.
The real browser flow runs a native `captchaNotRobot.*` chain and then issues a second `calls.getAnonymousToken` request with additional captcha continuation fields such as `success_token`, `captcha_sid`, `captcha_attempt`, and `captcha_ts`.

## What Changes
- Replace the current synthetic browser-owned stage-2 retry claim with a browser-observed native continuation path for VK captcha-gated stage 2.
- Let the controlled browser complete the native captcha continuation flow and observe the successful repeated `vk_calls_get_anonymous_token` response instead of constructing the continuation payload in Go.
- Keep provider resolution fail-closed until a usable browser-observed stage-2 result is captured and sanitized.
- Extend compatibility artifacts and tests so browser-observed success and explicit failure are anchored by sanitized evidence.

## Impact
- Affected specs: `vk-call-debug-contour`, `tunnel-client-runtime`
- Affected code: `internal/provider/vk`, `internal/providerprompt`, `cmd/probe`, `cmd/tunnel-client`, VK compatibility fixtures/tests, related docs
