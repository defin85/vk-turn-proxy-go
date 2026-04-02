# Change: Add runtime observability

## Why

Phase 1 explicitly calls for structured traces and metrics, but the current binaries only emit minimal startup logs.
As runtime behavior becomes real, operators and tests need explicit visibility into provider resolution, session startup, transport failures, and runtime health.

## What Changes

- Add structured runtime event logging for client, server, and provider-backed startup paths.
- Add metrics for session starts/failures, active workers, transport-stage failures, and forwarded traffic.
- Expose metrics through a documented runtime surface suitable for long-running binaries.
- Document the observability contract and how it maps to supported runtime behavior.

## Impact

- Affected specs: `runtime-observability`
- Related specs: `tunnel-client-runtime`, `session-supervision`, `vk-call-debug-contour`
- Affected code: `internal/observe`, `cmd/tunnel-client`, `cmd/tunnel-server`, `cmd/probe`, session/transport runtime code
