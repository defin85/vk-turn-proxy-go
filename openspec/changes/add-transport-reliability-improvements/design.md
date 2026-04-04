## Context

The repository already supports the accepted runtime matrix for provider-backed TURN/DTLS/plain UDP sessions.
What is not yet claimed is transport resilience over longer-lived sessions where TURN allocation refresh, permission refresh, NAT rebinding, or local socket behavior can degrade the dataplane after startup.

Source review of a related Go implementation shows two transport-side themes worth evaluating safely:

- explicit control over the packet/listener primitives used under TURN client startup
- transport plumbing that keeps allocation and permission maintenance anchored to listener-style sockets rather than one-shot dial semantics

This change must stay provider-agnostic and must not import any captcha bypass or hidden provider-state logic.

## Goals

- Improve the reliability of supported TURN UDP/TCP transport paths without changing provider contracts
- Preserve current startup ordering and stage-aware failure semantics
- Keep the implementation scoped to transport/session plumbing plus deterministic harness coverage
- Add evidence for long-lived session behavior instead of claiming improvements from inspection alone

## Non-Goals

- Captcha solving or anti-bot bypass
- New provider behavior
- Android-specific service/UI changes
- Expanding the supported policy matrix beyond what `tunnel-client-runtime` already accepts

## Decisions

### Decision: Treat reliability work as a modification of the canonical tunnel runtime

This change modifies `tunnel-client-runtime` rather than introducing a parallel capability.
The runtime contract remains canonical for startup, supervision, and supported transport modes.

### Decision: Prefer provider-agnostic transport hooks over provider-specific heuristics

Reliability work belongs in `internal/transport` and `internal/session`.
The provider layer must continue to resolve credentials and exit before transport starts.

### Decision: Add deterministic long-lived transport evidence before claiming parity improvements

Any improvement around allocation refresh or permission refresh must be backed by deterministic tests in `turnlab` and runtime integration coverage.
The repository must not claim mobile/NAT resilience solely from analogy to external code.

### Decision: Evaluate `ListenPacket`-style TURN client plumbing without silently widening behavior

The implementation may introduce a custom transport/net abstraction or migrate TURN client wiring if needed, but it must preserve explicit startup stages, cleanup, and fail-closed behavior.

## Alternatives Considered

### Pull transport changes together with captcha work

Rejected. It would mix provider anti-bot behavior with transport/runtime concerns and make acceptance evidence ambiguous.

### Claim reliability improvements from external source analysis only

Rejected. The repository requires requirement -> code -> test traceability.

## Risks / Trade-offs

- TURN client plumbing changes can regress startup/cleanup semantics if not isolated carefully.
- Longer-lived integration tests can become flaky if the harness is not extended deterministically.
- A migration to newer TURN client APIs may add code churn without proving a measurable reliability win.

## Validation Plan

- Deterministic harness support for exercising longer-lived allocation/refresh behavior
- Runtime integration tests that hold sessions long enough to cover allocation maintenance
- Explicit failure-path tests for cleanup when the new transport plumbing fails
- `go test ./...`, `go build ./...`, and strict OpenSpec validation
