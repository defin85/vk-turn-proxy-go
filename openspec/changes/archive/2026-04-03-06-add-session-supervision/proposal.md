# Change: Add session supervision

## Why

A single happy-path connection is not enough to satisfy the repository goal of a stable tunnel session lifecycle.
The rewrite needs explicit session supervision so transport workers, shutdown, and recovery behavior stay deterministic as the runtime grows.

## What Changes

- Introduce client-side session supervision as an explicit orchestration layer in `internal/session`.
- Support the configured connection count through supervised transport workers rather than one ad hoc runtime instance.
- Define restart, failure propagation, and coordinated shutdown behavior explicitly.
- Add lifecycle tests and operational docs for supervised sessions.

## Impact

- Affected specs: `session-supervision`
- Related specs: `tunnel-client-runtime`
- Affected code: `internal/session`, `internal/transport`, `cmd/tunnel-client`, lifecycle tests
