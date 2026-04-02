# Change: Add tunnel client runtime

## Why

The repository can now resolve live VK invites into normalized TURN credentials, but `cmd/tunnel-client` still exits before establishing any relay path.
Without a minimal runtime slice after provider resolution, the rewrite cannot prove that provider-backed credentials actually produce a working tunnel session.

## What Changes

- Implement a minimal client runtime that turns provider-resolved TURN credentials plus a configured peer server into one live relay session.
- Wire `cmd/tunnel-client` to run the real session bootstrap and transport runtime instead of exiting after `adapter.Resolve(...)`.
- Keep provider resolution inside `internal/provider/...` and move relay/session orchestration into `internal/session` and `internal/transport`.
- Add integration tests for end-to-end UDP forwarding against local server scaffolds and explicit startup failure cases.
- Document the supported first-slice policy matrix and the differences from the legacy multi-connection client.

## Impact

- Affected specs: `tunnel-client-runtime`
- Related specs: `generic-turn-provider`, `turn-lab-harness`, `vk-call-debug-contour`
- Affected code: `cmd/tunnel-client`, `internal/session`, `internal/transport`, `internal/config`, test/integration harnesses
