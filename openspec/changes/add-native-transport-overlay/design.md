## Context

The current canonical runtime is intentionally narrow:

- client ingress is a local UDP listener
- server egress is a UDP upstream target
- worker/session plumbing exchanges `RelayPacket{Payload, ReplyTo}` datagrams
- reply routing is currently keyed to the most recent local sender for the supported UDP slice

That is enough to carry "any traffic" only when another transport layer such as WireGuard sits on top of the repository.
The legacy prototype was often used that way in practice, but the canonical repository does not yet expose native stream-aware transport primitives of its own.

The goal of this change is not to promise every protocol in one step.
The goal is to define a safe native overlay architecture that keeps provider resolution and TURN/DTLS underlay behavior intact while making room for native adapters above that underlay.

## Goals

- Introduce explicit client ingress and server egress adapters above the current underlay
- Preserve provider-specific signaling boundaries and the current UDP baseline behavior
- Support both datagram-class and stream-class overlay sessions with explicit identity and teardown
- Define a realistic first native stream slice so future work does not need another architectural reset
- Keep unsupported adapter pairings fail-closed during startup

## Non-Goals

- Implement every application-layer protocol in one change
- Change VK or other provider signaling behavior
- Replace the current TURN/DTLS/plain underlay with a different relay protocol
- Add OS-specific route management or TUN-device orchestration in this change
- Claim mobile rebinding or broad production parity from architecture alone

## Decisions

### Decision: Add a native overlay layer above the existing underlay

The current provider-backed TURN/DTLS/plain path remains the underlay.
New local and upstream protocol support belongs in a distinct overlay layer above `internal/session` and `internal/transport`, not inside provider adapters.

### Decision: Separate ingress adapters from egress adapters

Client-side local protocol handling and server-side upstream protocol handling have different responsibilities and failure modes.
The architecture should model them independently instead of hard-coding "UDP on both ends" into the session contract.

### Decision: Distinguish datagram sessions from stream sessions explicitly

The current `ReplyTo net.Addr` model is sufficient for UDP datagrams but not for native TCP or proxy-style stream handling.
The overlay contract should carry explicit session identity and lifecycle metadata so stream setup, teardown, and backpressure are first-class concerns.

### Decision: Preserve UDP -> UDP as the migration baseline

The first adapter pair must continue to represent the current behavior so the migration does not widen scope and silently break working UDP transport.
UDP baseline coverage remains the acceptance anchor while new adapters are added.

### Decision: Make native TCP the first non-UDP slice

Native TCP is the smallest realistic step beyond the current datagram-only contract.
Higher-level adapters such as SOCKS5 or HTTP CONNECT should build on top of a stream-capable overlay layer instead of forcing protocol-specific hacks into the first change.

### Decision: Reject unsupported adapter pairings before transport startup

The runtime must not silently downgrade unsupported stream or proxy configurations into UDP behavior.
Unsupported ingress/egress combinations should fail during policy validation or another explicit startup stage before provider resolution claims success.

## Alternatives Considered

### Keep the repository UDP-only and rely on external overlays forever

Rejected.
That keeps the canonical codebase from owning the "general transport" story and leaves native protocol support outside the repository boundary.

### Add SOCKS5 or HTTP CONNECT directly without a generic overlay contract

Rejected.
That would entangle application-proxy concerns with runtime plumbing before stream identity and teardown semantics are defined.

### Tunnel raw TCP by coercing it into datagram-only routing

Rejected.
Native stream support needs explicit session identity, teardown propagation, and backpressure handling.

## Risks / Trade-offs

- Overlay session management adds complexity beyond the current datagram router
- Stream multiplexing over a datagram underlay can introduce head-of-line blocking, buffering, and cleanup hazards
- Adapter explosion can blur the supported matrix unless the repository documents pairings explicitly
- Migration from `RelayPacket{Payload, ReplyTo}` to a richer overlay envelope can regress the working UDP baseline if not staged carefully

## Validation Plan

- Deterministic tests that preserve the current UDP baseline through the adapter layer
- Integration coverage for at least one native stream adapter pair before that pair is claimed as supported
- Explicit docs and compatibility notes for every supported adapter pairing
- `go test ./...`, `go build ./...`, and `openspec validate add-native-transport-overlay --strict --no-interactive`

## Open Questions

- Whether SOCKS5 or TUN should be the next adapter after native TCP is intentionally deferred to follow-up changes
