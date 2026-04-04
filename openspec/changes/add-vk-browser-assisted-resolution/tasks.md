## 1. Browser-assisted provider contract
- [x] 1.1 Add a typed browser-assisted continuation contract for provider interaction without widening transport/runtime boundaries
- [x] 1.2 Define how `vk` stage 2 resumes using controlled browser session state and how failures remain explicit

## 2. CLI and provider integration
- [x] 2.1 Add browser-assisted interactive provider handling to `cmd/probe`
- [x] 2.2 Add browser-assisted interactive provider handling to `cmd/tunnel-client`
- [x] 2.3 Ensure provider resolution still completes before any local listener or TURN transport startup

## 3. Evidence and verification
- [x] 3.1 Add compatibility fixtures/tests for browser-assisted success and failure paths
- [x] 3.2 Document operator workflow and redaction rules for browser-assisted mode
- [x] 3.3 Run `openspec validate add-vk-browser-assisted-resolution --strict --no-interactive`
