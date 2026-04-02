## 1. Runtime contract

- [ ] 1.1 Define the supported first-slice client policy matrix for `cmd/tunnel-client`, including explicit unsupported combinations.
- [ ] 1.2 Bind the runtime contract to the deterministic provider and TURN lab harness introduced by the preceding roadmap changes.

## 2. Client runtime implementation

- [ ] 2.1 Add provider-backed session bootstrap in `internal/session` that resolves credentials, applies TURN endpoint overrides, and validates startup policy.
- [ ] 2.2 Implement a provider-agnostic client transport runner in `internal/transport` for one UDP-based TURN allocation, one DTLS client wrapper, and bidirectional forwarding.
- [ ] 2.3 Wire `cmd/tunnel-client` to the new runtime with explicit startup/shutdown logging and exit-code behavior.

## 3. Verification and handoff

- [ ] 3.1 Add unit and integration tests for successful startup, bidirectional UDP forwarding, unsupported policy rejection, provider resolution failure, and TURN/DTLS startup failure.
- [ ] 3.2 Document the supported runtime slice, operator workflow, and remaining gaps versus the legacy multi-connection client.
