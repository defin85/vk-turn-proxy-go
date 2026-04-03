## 1. Policy contract

- [x] 1.1 Modify the canonical `tunnel-client-runtime` spec delta to define the expanded supported one-session policy matrix and the remaining unsupported combinations.
- [x] 1.2 Define `mode=udp|tcp|auto` semantics precisely, including that `mode=tcp` affects only the client-to-TURN hop and `mode=auto` remains the documented default path.
- [x] 1.3 Define `bind-interface` as a literal local IP outbound bind target only, plus explicit fail-closed cases for unsupported values and unappliable bind targets.
- [x] 1.4 Define the stage taxonomy updates required for DTLS-off and transport-neutral peer setup failures.

## 2. Implementation

- [x] 2.1 Introduce a session-level transport plan that selects TURN transport mode, peer relay mode, and outbound bind target before startup.
- [x] 2.2 Implement UDP and TCP TURN startup paths for the supported one-session combinations.
- [x] 2.3 Implement DTLS-off runtime behavior as a plain datagram relay path instead of a bool branch inside the existing DTLS runner.
- [x] 2.4 Implement outbound bind-target plumbing for literal local IP values and explicit errors for unsupported or unappliable bind targets.

## 3. Verification and docs

- [x] 3.1 Extend deterministic harness coverage for TURN-over-TCP and DTLS-off startup paths.
- [x] 3.2 Add unit and integration tests for every newly supported combination plus fail-closed rejects that remain unsupported.
- [x] 3.3 Refresh VK runtime compatibility evidence for every VK-backed combination this change claims as supported.
- [x] 3.4 Document the final supported matrix, defaults, and explicit remaining unsupported items.
