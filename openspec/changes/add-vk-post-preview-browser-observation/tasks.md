## 1. Post-preview contour
- [ ] 1.1 Define a provider-scoped VK post-preview browser contour that captures browser-observed requests and responses after `calls.getCallPreview`
- [ ] 1.2 Distinguish preview-only, post-preview unsupported, and transport-ready post-preview outcomes instead of treating preview as the final live contour
- [ ] 1.3 Keep `cmd/probe` and `cmd/tunnel-client` fail-closed until post-preview observation yields normalized TURN credentials or an explicit unsupported provider result

## 2. Evidence and docs
- [ ] 2.1 Add sanitized compatibility fixtures/tests for at least one post-preview contour outcome
- [ ] 2.2 Update VK provider docs to describe preview-only versus post-preview observation boundaries without overclaiming parity

## 3. Verification
- [ ] 3.1 Run the smallest relevant VK provider / prompt / probe / tunnel-client test set
- [ ] 3.2 Run `go test ./...`
- [ ] 3.3 Run `go build ./...`
- [ ] 3.4 Run `openspec validate add-vk-post-preview-browser-observation --strict --no-interactive`
