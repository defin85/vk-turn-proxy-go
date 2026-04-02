# Change: Add VK call debug contour

## Why

The Go rewrite cannot yet resolve VK call invites into TURN credentials: the VK provider adapter is still a stub and explicitly waits for compatibility fixtures.
Porting the legacy client blindly would risk mixing provider-specific HTTP flow with transport code and would make regressions hard to prove.

## What Changes

- Add a VK-specific debug contour that resolves a VK call invite into normalized TURN credentials without starting the transport runtime.
- Capture and store sanitized probe artifacts so the legacy repository can act as a compatibility oracle for the staged VK HTTP flow.
- Add compatibility tests for invite normalization, staged VK credential resolution, and failure handling.
- Document the workflow for using the debug contour before porting the broader legacy client functionality.

## Impact

- Affected specs: `vk-call-debug-contour`
- Affected code: `cmd/probe`, `internal/provider/vk`, `internal/config`, `internal/observe`, `test/compatibility`

## Acceptance Notes

- On April 2, 2026, a live `cmd/probe` run against a redacted VK invite completed all four provider stages and returned a normalized TURN address.
- The same live run persisted a sanitized probe artifact without storing the raw invite token in the artifact file.
- On April 2, 2026, `cmd/tunnel-client` still exited after provider resolution with `client transport core is not ported yet`; this change is accepted as a provider-only debug contour and does not claim live TURN/DTLS/session connectivity.
