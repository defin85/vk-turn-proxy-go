## 1. API contract
- [x] 1.1 Define the local control-plane schema for profiles, sessions, challenges, diagnostics, and capability negotiation
- [x] 1.2 Define desktop sidecar and mobile host-bridge expectations without creating separate semantic contracts

## 2. Runtime integration
- [x] 2.1 Introduce control-plane-aware runtime primitives that do not depend on parsing CLI output
- [x] 2.2 Add typed event streaming for lifecycle, challenge, readiness, retry, and failure states

## 3. Verification
- [x] 3.1 Add unit and integration coverage for the control plane
- [x] 3.2 Run `go test ./...`
- [x] 3.3 Run `go build ./...`
- [x] 3.4 Run `openspec validate add-01-client-control-plane --strict --no-interactive`
