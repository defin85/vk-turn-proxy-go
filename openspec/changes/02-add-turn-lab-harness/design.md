## Context

The server baseline already exists, but there is no deterministic way to prove a full client relay path in tests.
A lab harness should exercise the same transport stages the real runtime will depend on: TURN auth/allocation, DTLS to the tunnel server, and UDP forwarding to an upstream target.

## Goals

- Provide one reusable local harness for transport integration tests.
- Avoid live provider dependencies in CI.
- Keep the harness reusable by both tests and manual smoke workflows.

## Non-Goals

- Shipping a production TURN service in this repository.
- Replacing provider-level acceptance for VK.
- Testing every future transport policy combination in the first harness slice.

## Decisions

- Build the harness around an in-process TURN server with deterministic static credentials.
- Reuse the existing DTLS tunnel server behavior for the peer side of the relay path.
- Include a simple upstream UDP echo endpoint so tests can assert bidirectional forwarding.
- Return a typed harness descriptor with listen addresses, peer address, TURN endpoint, and credentials for test setup.
- Keep the harness in Go test support code rather than as a long-running product binary.

## Alternatives Considered

- Mock TURN allocation instead of running a real TURN server.
  Rejected because it would miss the most failure-prone startup stage.
- Depend on external docker-compose services in CI.
  Rejected because the repository currently has a simpler single-process Go workflow.

## Risks / Trade-offs

- Real TURN integration tests will be slower than pure unit tests.
  Mitigation: keep the harness small, deterministic, and scoped to targeted integration tests.
- Introducing a TURN test dependency raises maintenance cost.
  Mitigation: keep the harness isolated to test support and version-pin the dependency.

## Migration Plan

1. Add the in-process TURN harness and typed fixture API.
2. Add one smoke test that proves relay connectivity through the harness.
3. Reuse the harness in the tunnel client runtime changes that follow.
