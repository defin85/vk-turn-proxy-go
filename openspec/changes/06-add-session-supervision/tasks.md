## 1. Lifecycle contract

- [ ] 1.1 Define the supervised worker lifecycle, including startup, cancellation, and failure propagation.
- [ ] 1.2 Define which failures trigger restart versus full session failure in the supported modes.

## 2. Implementation

- [ ] 2.1 Implement supervised worker startup based on `connections`.
- [ ] 2.2 Implement coordinated cleanup across listeners, TURN resources, and transport workers.
- [ ] 2.3 Implement explicit lifecycle errors and restart behavior where declared.

## 3. Verification and docs

- [ ] 3.1 Add lifecycle tests for multi-worker startup, partial failure, restart, and shutdown.
- [ ] 3.2 Document the supervised-session model and remaining gaps versus legacy heuristics.
