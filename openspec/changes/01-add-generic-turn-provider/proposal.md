# Change: Add generic TURN provider

## Why

The repository needs one deterministic provider path that does not depend on live VK behavior.
A static TURN provider gives lab runs, integration tests, and operator smoke checks a stable credential source while keeping the provider boundary intact.

## What Changes

- Add a `generic-turn` provider adapter that resolves static TURN credentials from a provider link.
- Support the provider in `cmd/probe` and `cmd/tunnel-client` through the existing registry contract.
- Persist a sanitized provider artifact so probe runs stay comparable with other providers.
- Document the link format and failure behavior for local and CI use.

## Impact

- Affected specs: `generic-turn-provider`
- Related specs: `vk-call-debug-contour`
- Affected code: `internal/provider`, `internal/provider/genericturn`, `cmd/probe`, `cmd/tunnel-client`, docs/provider matrix
