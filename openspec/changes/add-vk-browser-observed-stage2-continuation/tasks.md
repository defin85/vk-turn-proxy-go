## 1. Browser-observed continuation
- [x] 1.1 Define and implement a provider-scoped contract for observing the native browser-owned continuation of VK stage 2 after captcha completion
- [x] 1.2 Keep `cmd/probe` and `cmd/tunnel-client` fail-closed so no local listener or TURN transport starts before a usable browser-observed stage-2 result is captured

## 2. Evidence and sanitization
- [x] 2.1 Add compatibility fixtures/tests for browser-observed stage-2 success and explicit browser-observed failure
- [x] 2.2 Prove that persisted artifacts redact raw browser state, `session_token`, `success_token`, captcha continuation fields, challenge URLs, and request-param secret values
- [x] 2.3 Update VK provider docs to describe the supported browser-observed continuation contract without overclaiming live VK parity

## 3. Verification
- [x] 3.1 Run the smallest relevant VK provider / prompt / probe / tunnel-client test set
- [x] 3.2 Run `go test ./...`
- [x] 3.3 Run `go build ./...`
- [x] 3.4 Run `openspec validate add-vk-browser-observed-stage2-continuation --strict --no-interactive`
