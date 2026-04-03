# Change: Add TURN lab harness

## Why

The repository needs deterministic end-to-end transport evidence before implementing more runtime behavior.
Today there is no reusable local harness that can exercise TURN allocation, the DTLS tunnel server, and UDP forwarding without live provider dependencies.

## What Changes

- Add a reusable local lab harness for integration tests and operator smoke runs.
- Start a local TURN server with static auth, a local DTLS tunnel server, and an upstream UDP echo target under one orchestrated fixture.
- Expose deterministic endpoints and credentials so later runtime changes can test real relay paths without VK.
- Document how the harness is used in CI and local debugging.

## Impact

- Affected specs: `turn-lab-harness`
- Related specs: `generic-turn-provider`, `tunnel-client-runtime`
- Affected code: integration test harnesses, `internal/transport` test support, docs
