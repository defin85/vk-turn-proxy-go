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

- Introduce an explicit client session bootstrap that performs: semantic policy validation -> provider resolution -> TURN endpoint override application -> transport startup.
- Keep `config.Validate()` syntax-only; move semantic startup policy validation into `internal/session/...` so unsupported first-slice configs fail before provider resolution or transport startup.
- The supported first runtime slice is exactly `connections=1`, `dtls=true`, `mode=udp|auto`, and an empty `bind-interface`; `mode=auto` normalizes to the UDP transport path for this slice.
- Unsupported combinations such as `connections != 1`, `mode=tcp`, `dtls=false`, or non-empty `bind-interface` must fail before provider resolution with explicit unsupported-config errors rather than silent fallback behavior.
- Apply `-turn` and `-port` overrides after provider resolution so operators can reuse provider credentials with an alternate TURN endpoint when debugging.
- The transport startup order for the first slice is: bind local UDP listener -> create TURN base socket -> TURN client listen/allocate -> DTLS client over the allocated relay `PacketConn` -> forwarding loops.
- Keep relay/TURN/DTLS code provider-agnostic inside `internal/transport/...`; pass only normalized credentials and peer/listen configuration into that layer, and do not add an intermediate DTLS-before-TURN wrapper layer.
- Keep orchestration and lifecycle in `internal/session/...`; keep `cmd/tunnel-client` flag parsing and exit-code mapping only.
- The first runtime slice uses single-local-peer reply semantics: the runtime tracks the most recently observed local UDP source address for the session and emits peer replies back to that address only.
- Startup and runtime failures use a typed stage taxonomy at the session boundary: `policy_validate`, `provider_resolve`, `local_bind`, `turn_dial`, `turn_allocate`, `dtls_handshake`, and `forwarding_loop`.
- Follow-up changes own the broader matrix: `05-expand-transport-policy-matrix` adds real `bind-interface`, `mode=tcp`, and `dtls=false` behavior; `06-add-session-supervision` owns `connections > 1`.
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
  Mitigation: define the supported matrix explicitly in spec, fail unsupported combinations before provider resolution, and document rejected flags such as `bind-interface`.
- Single-local-peer reply routing is narrower than the legacy client's eventual behavior.
  Mitigation: define the reply-routing contract explicitly, cover it with integration tests, and leave broader worker/local-peer handling to follow-up changes.
- Manual live VK verification can still drift independently from CI.
  Mitigation: keep CI provider-agnostic and use live VK only as post-implementation acceptance evidence.
- Stage-aware errors introduce more surface area at the session boundary.
  Mitigation: keep the taxonomy small, fixed, and mapped directly to bootstrap/transport phases.

## Migration Plan

1. Define the first runtime capability, supported policy matrix, single-local-peer semantics, and stage taxonomy.
2. Reuse the deterministic provider and lab harness to implement session bootstrap with semantic policy gating in `internal/session`.
3. Implement the provider-agnostic client transport runner with TURN allocation before the DTLS client wrapper.
4. Wire `cmd/tunnel-client` to the new runtime and remove the stub exit path.
5. Add integration coverage against local server scaffolds plus explicit policy/provider/TURN/DTLS failure tests.
