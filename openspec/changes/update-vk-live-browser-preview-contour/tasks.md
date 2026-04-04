## 1. Live browser contour
- [x] 1.1 Define a provider-scoped live VK browser preview contour that starts after challenge completion and captures browser-observed `get_anonym_token(messages)` plus `calls.getCallPreview`
- [x] 1.2 Keep the deterministic legacy staged contour as separate compatibility evidence instead of silently replacing it
- [x] 1.3 Keep `cmd/probe` and `cmd/tunnel-client` fail-closed until the live browser contour yields TURN credentials or an explicit preview-only / unsupported provider result

## 2. Evidence and docs
- [x] 2.1 Add sanitized compatibility fixtures/tests for the live browser preview contour and its explicit failure or preview-only outcome
- [x] 2.2 Update VK provider docs to distinguish the deterministic legacy contour from the live browser contour without overclaiming parity

## 3. Verification
- [x] 3.1 Run the smallest relevant VK provider / prompt / probe / tunnel-client test set
- [x] 3.2 Run `go test ./...`
- [x] 3.3 Run `go build ./...`
- [x] 3.4 Run `openspec validate update-vk-live-browser-preview-contour --strict --no-interactive`
