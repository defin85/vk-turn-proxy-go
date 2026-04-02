## 1. Harness contract

- [ ] 1.1 Define the lab harness fixture contract, including emitted addresses, credentials, and cleanup semantics.
- [ ] 1.2 Define the first smoke-test scenario that proves a relay round-trip through the harness.

## 2. Harness implementation

- [ ] 2.1 Implement an in-process TURN test server with deterministic static auth.
- [ ] 2.2 Add orchestration for the DTLS tunnel server and upstream UDP echo target.

## 3. Verification and docs

- [ ] 3.1 Add integration tests that start the full harness and verify cleanup.
- [ ] 3.2 Document how later runtime changes should consume the harness.
