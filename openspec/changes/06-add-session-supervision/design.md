## Context

The legacy client keeps multiple transport workers alive and reacts to failures over time.
The rewrite currently has only a session identifier helper and no explicit lifecycle model for transport workers.

## Goals

- Make session lifecycle and worker orchestration explicit.
- Support the configured connection count through a supervised model.
- Ensure cancellation and partial failures release resources deterministically.

## Non-Goals

- Recreating every legacy reconnection heuristic verbatim.
- Adding provider-specific behavior to the session layer.
- Expanding transport policy support beyond what the transport layer already exposes.

## Decisions

- `internal/session` becomes the owner of worker startup, cancellation, and error aggregation.
- The configured `connections` value determines the number of transport workers for supported runtime modes.
- The supervisor defines explicit policy for worker failure: restart where declared, otherwise fail the session with a named lifecycle error.
- Shutdown is context-driven and must close listeners, TURN allocations, DTLS/plain transport connections, and worker goroutines.

## Risks / Trade-offs

- Worker supervision can become a hidden transport abstraction leak.
  Mitigation: keep `internal/session` focused on orchestration and keep transport details inside `internal/transport`.
- Restart behavior can be hard to test deterministically.
  Mitigation: inject clocks/backoff and use explicit lifecycle tests.

## Migration Plan

1. Define the lifecycle contract for supervised sessions.
2. Implement worker orchestration and cleanup.
3. Add tests for startup, partial failure, restart policy, and shutdown.
