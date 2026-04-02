## Context

The archived `vk-call-debug-contour` change established that the Go rewrite can resolve a live VK invite into TURN credentials and persist sanitized provider-stage artifacts.
The ordered roadmap for this repository assumes a deterministic `generic-turn` provider and a reusable TURN lab harness are available before the first real client runtime slice lands.
The next missing slice is the client runtime itself: `cmd/tunnel-client` currently resolves provider credentials and then exits with `client transport core is not ported yet`.

The legacy repository already combines local UDP listening, optional DTLS, TURN allocation, and UDP forwarding, but it does so in one large client flow with multi-connection behavior and mixed concerns.
This change intentionally ports only the smallest runtime slice needed to prove a real client session path in the rewrite.

## Goals

- Start one real provider-backed tunnel client session after successful provider resolution.
- Keep provider-specific signaling out of the transport runtime.
- Prove bidirectional UDP forwarding through the client relay path against a local server harness.
- Fail closed on unsupported policies and transport-stage startup errors.

## Non-Goals

- Porting the full legacy multi-connection client or its connection recycling behavior.
- Supporting every existing CLI combination in the first runtime slice.
- Adding new provider integrations beyond the existing VK resolver.
- Reworking the server-side transport architecture beyond what is needed for local integration tests.

## Decisions

- Introduce an explicit client session bootstrap that performs: provider resolution -> startup policy validation -> TURN endpoint override application -> local UDP listener setup -> DTLS wrapper -> TURN allocation -> forwarding loops.
- Keep relay/TURN/DTLS code provider-agnostic inside `internal/transport/...`; pass only normalized credentials and peer/listen configuration into that layer.
- Keep orchestration and lifecycle in `internal/session/...`; keep `cmd/tunnel-client` flag parsing and exit-code mapping only.
- The first runtime slice supports exactly one connection with `connections=1`, `dtls=true`, and `mode=auto|udp`; `mode=auto` normalizes to the UDP transport path for this slice.
- Unsupported combinations such as `connections != 1`, `mode=tcp`, or `dtls=false` must fail before session startup with explicit unsupported-config errors rather than silent fallback behavior.
- `-turn` and `-port` overrides apply after provider resolution so operators can reuse provider credentials with an alternate TURN endpoint when debugging.
- CI verification uses the deterministic lab harness and non-live providers; live VK invite checks remain manual acceptance evidence, not CI requirements.

## Alternatives Considered

- Port the full legacy client in one change.
  Rejected because it would mix baseline runtime proof, unsupported modes, and multi-connection behavior into one acceptance target.
- Extend `vk-call-debug-contour` instead of creating a new runtime capability.
  Rejected because provider-only resolution and client transport runtime are different layers with different acceptance evidence.
- Keep `cmd/tunnel-client` as a stub until all legacy modes are understood.
  Rejected because the repository already has enough provider evidence to deliver one real session path now.

## Risks / Trade-offs

- TURN allocation and DTLS startup add goroutine and shutdown complexity.
  Mitigation: keep one-session scope, context-driven teardown, and integration tests that assert cleanup and explicit errors.
- The first runtime slice supports fewer CLI combinations than the existing config surface suggests.
  Mitigation: define the supported matrix explicitly in spec and fail unsupported combinations before network startup.
- Manual live VK verification can still drift independently from CI.
  Mitigation: keep CI provider-agnostic and use live VK only as post-implementation acceptance evidence.

## Migration Plan

1. Define the first runtime capability and supported policy matrix.
2. Reuse the deterministic provider and lab harness to implement session bootstrap and the provider-agnostic client transport runner.
3. Wire `cmd/tunnel-client` to the new runtime and remove the stub exit path.
4. Add integration coverage against local server scaffolds plus explicit unsupported-policy tests.
5. Record manual live acceptance once the runtime path is working end-to-end.

## Open Questions

- Whether interface pinning via `-bind-interface` must be part of the first runtime slice or can remain a follow-up once the single-session path is stable.
