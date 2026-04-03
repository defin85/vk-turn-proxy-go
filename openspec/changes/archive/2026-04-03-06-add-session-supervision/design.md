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
- The session layer owns one shared local UDP listener and dispatches datagrams to supervised transport workers instead of letting every worker bind the same listen address independently.
- The supervisor defines explicit policy for worker failure:
  startup failures before a worker reports ready fail the whole session with the worker's transport stage;
  runtime failures after readiness are restarted with a fixed backoff;
  restart-budget exhaustion fails the session with `session_supervision`.
- Shutdown is context-driven and must close listeners, TURN allocations, DTLS/plain transport connections, and worker goroutines.

## Supervision Policy

- Startup contract:
  the session binds the local UDP listener after provider resolution, starts the configured number of workers, and only treats the session as ready after every worker has reported readiness.
- Restart policy:
  a worker that fails after readiness is restarted with deterministic backoff; the rewrite currently allows one runtime restart per worker before surfacing a lifecycle failure.
- Routing contract:
  local datagrams are dispatched round-robin across ready workers;
  reply routing remains "most recent local sender" within each worker and does not yet claim stable multi-peer demultiplexing across the whole supervised session.
- Shutdown contract:
  context cancellation interrupts the shared local listener, cancels all workers, and waits for every goroutine to exit before `Run` returns.

## Risks / Trade-offs

- Worker supervision can become a hidden transport abstraction leak.
  Mitigation: keep `internal/session` focused on orchestration and keep transport details inside `internal/transport`.
- Restart behavior can be hard to test deterministically.
  Mitigation: inject clocks/backoff and use explicit lifecycle tests.

## Migration Plan

1. Define the lifecycle contract for supervised sessions.
2. Implement worker orchestration and cleanup.
3. Add tests for startup, partial failure, restart policy, and shutdown.
