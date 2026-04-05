# Change: Add VK post-preview browser observation

## Why
Live invite runs on April 4, 2026 now converge on a repeatable browser-observed preview contour: after captcha the controlled browser reaches `calls.getCallPreview`, but the provider still does not observe normalized TURN credentials. That proves the current preview-only contour is real, but it is still insufficient to explain where live browser sessions become transport-ready.

The next step is to extend observation beyond preview in a fail-closed way so the repository can capture the post-preview browser contour without guessing payloads or claiming TURN parity too early.

## What Changes
- Extend the VK browser-observed debug contour so `cmd/probe` can capture sanitized post-preview requests and responses that happen after the operator proceeds from the pre-join UI.
- Distinguish preview-only evidence from post-preview evidence instead of collapsing both into one terminal result.
- Keep `cmd/probe` and `cmd/tunnel-client` fail-closed until post-preview observation yields normalized TURN credentials or an explicit unsupported post-preview result.
- Add replayable sanitized fixtures/tests and docs for the new post-preview contour.

## Impact
- Affected specs: `vk-call-debug-contour`, `tunnel-client-runtime`
- Affected code: `internal/provider/vk`, `internal/providerprompt`, `cmd/probe`, `cmd/tunnel-client`, VK compatibility fixtures/tests, related docs
