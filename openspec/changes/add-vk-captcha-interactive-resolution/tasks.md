## 1. Provider challenge model
- [x] 1.1 Add a typed VK captcha challenge/error model plus sanitized artifact encoding for `captcha_required`
- [x] 1.2 Add fixture-backed provider tests for non-interactive `captcha_required` failure and interactive resumed success

## 2. CLI interactive flow
- [x] 2.1 Add explicit opt-in interactive provider mode to `cmd/probe`
- [x] 2.2 Add explicit opt-in interactive provider mode to `cmd/tunnel-client`
- [x] 2.3 Ensure `tunnel-client` does not bind local transport resources before interactive provider resolution succeeds

## 3. Verification
- [x] 3.1 Add regression tests for redaction, retry behavior, and explicit non-interactive failure
- [x] 3.2 Run `go test ./cmd/probe ./cmd/tunnel-client ./internal/provider/vk`
- [x] 3.3 Run `go test ./...`
- [x] 3.4 Run `go build ./...`
- [x] 3.5 Run `openspec validate add-vk-captcha-interactive-resolution --strict --no-interactive`
