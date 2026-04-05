# Change: Add operator-assisted VK captcha continuation

## Why
Live VK invite resolution now frequently returns `Captcha needed` during `calls.getAnonymousToken`.
The current provider fails closed immediately, which blocks real operator workflows even when a human could complete the VK challenge and continue the staged resolution safely.

## What Changes
- Add explicit VK captcha challenge detection with sanitized artifacts and machine-readable provider errors.
- Add an operator-assisted interactive continuation path for `cmd/probe` and `cmd/tunnel-client` so resolution can pause for human captcha completion and then retry stage 2.
- Keep non-interactive behavior fail-closed with an explicit `captcha_required` provider failure.
- Add compatibility fixtures and tests for captcha-required and resumed-resolution scenarios.

## Impact
- Affected specs: `vk-call-debug-contour`, `tunnel-client-runtime`
- Affected code: `internal/provider/vk`, `cmd/probe`, `cmd/tunnel-client`, provider compatibility tests
