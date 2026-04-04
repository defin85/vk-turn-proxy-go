# Change: Update VK live browser preview contour

## Why
Live browser tracing on April 4, 2026 showed that current VK invite handling no longer follows the assumed post-captcha `calls.getAnonymousToken` replay path. After `challenge.html`, the browser reached the pre-join page by using a different contour centered on `login.vk.com/?act=get_anonym_token` and `api.vk.com/method/calls.getCallPreview`.

The current rewrite therefore fails in the wrong place: it keeps waiting for a repeated `vk_calls_get_anonymous_token` request that does not occur in the observed live flow.

## What Changes
- Add an explicit browser-observed live VK preview contour for post-challenge invite handling.
- Distinguish the deterministic legacy staged contour from the live browser contour instead of treating them as the same stage sequence.
- Let the provider capture structured browser-side results for `get_anonym_token(messages)` and `calls.getCallPreview`.
- Keep `cmd/probe` and `cmd/tunnel-client` fail-closed until the live browser contour either yields normalized TURN credentials or returns an explicit preview-only / unsupported provider result.
- Add replayable sanitized evidence for the observed live browser contour and document that it is a different contract from the legacy `getVkCreds` path.

## Impact
- Affected specs: `vk-call-debug-contour`, `tunnel-client-runtime`
- Affected code: `internal/provider/vk`, `internal/providerprompt`, `cmd/probe`, `cmd/tunnel-client`, VK compatibility fixtures/tests, related docs
