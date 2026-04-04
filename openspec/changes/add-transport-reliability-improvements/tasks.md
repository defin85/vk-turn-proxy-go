## 1. Transport plumbing
- [x] 1.1 Design and implement provider-agnostic TURN client plumbing changes needed for reliability improvements
- [x] 1.2 Preserve current startup stages, cleanup guarantees, and fail-closed behavior while applying the new plumbing

## 2. Deterministic evidence
- [x] 2.1 Extend `turnlab` to exercise long-lived allocation or permission-refresh behavior deterministically
- [x] 2.2 Add runtime integration tests covering the improved long-lived transport path and failure cleanup
- [x] 2.3 Update runtime docs to describe the supported reliability guarantees without overclaiming mobile/NAT parity

## 3. Verification
- [x] 3.1 Run the smallest relevant transport/session/turnlab test set
- [x] 3.2 Run `go test ./...`
- [x] 3.3 Run `go build ./...`
- [x] 3.4 Run `openspec validate add-transport-reliability-improvements --strict --no-interactive`
