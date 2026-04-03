# Change: Add tunnel client runtime

## Why

The repository can now resolve live VK invites into normalized TURN credentials, but `cmd/tunnel-client` still exits before establishing any relay path.
Without a minimal runtime slice after provider resolution, the rewrite cannot prove that provider-backed credentials actually produce a working tunnel session.

## What Changes

- Define a narrow first-slice runtime contract that validates semantic policy before provider resolution and starts exactly one provider-backed UDP/DTLS relay session.
- Wire `cmd/tunnel-client` to run the real session bootstrap and transport runtime instead of exiting after `adapter.Resolve(...)`.
- Keep provider resolution inside `internal/provider/...` and move policy gating, stage-aware bootstrap errors, and relay/session orchestration into `internal/session` and `internal/transport`.
- Treat `connections != 1`, `mode=tcp`, `dtls=false`, and non-empty `-bind-interface` as explicit first-slice unsupported configs instead of silent fallbacks.
- Define the first-slice reply-routing contract as one active local UDP peer per session and cover it with deterministic integration tests.
- Document the supported runtime slice, rejected flags, and the differences from the legacy multi-connection client.

## Impact

- Affected specs: `tunnel-client-runtime`
- Related specs: `generic-turn-provider`, `turn-lab-harness`, `vk-call-debug-contour`
- Affected code: `cmd/tunnel-client`, `internal/session`, `internal/transport`, `internal/config`, test/integration harnesses
