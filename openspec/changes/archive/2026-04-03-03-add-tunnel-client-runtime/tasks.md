## 1. Runtime contract

- [x] 1.1 Define the supported first-slice client policy matrix for `cmd/tunnel-client`, including `mode=auto|udp`, `dtls=true`, empty `bind-interface`, explicit unsupported combinations, and single-local-peer reply semantics.
- [x] 1.2 Bind the runtime contract to the deterministic provider and TURN lab harness introduced by the preceding roadmap changes.
- [x] 1.3 Define the first-slice bootstrap order and stage-aware error taxonomy.

## 2. Client runtime implementation

- [x] 2.1 Add provider-backed session bootstrap in `internal/session` that keeps `config.Validate()` syntax-only, validates semantic policy before provider resolution, applies TURN endpoint overrides, and returns typed stage errors.
- [x] 2.2 Implement a provider-agnostic client transport runner in `internal/transport` for one UDP-based TURN allocation, one DTLS client over the allocated relay `PacketConn`, and bidirectional forwarding with single-local-peer reply routing.
- [x] 2.3 Wire `cmd/tunnel-client` to the new runtime with explicit stage-aware startup/shutdown logging and exit-code behavior.

## 3. Verification and handoff

- [x] 3.1 Add unit and integration tests for successful startup, bidirectional UDP forwarding, single-local-peer routing, unsupported policy rejection before provider resolution, provider resolution failure, and TURN/DTLS startup failure.
- [x] 3.2 Document the supported runtime slice, rejected first-slice flags such as `bind-interface`, operator workflow, and remaining gaps versus the legacy multi-connection client.
