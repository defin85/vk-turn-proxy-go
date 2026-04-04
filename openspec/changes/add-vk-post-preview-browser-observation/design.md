## Context

The repository now captures a live browser contour up to `vk_calls_get_call_preview` and fails closed with `browser_preview_only`.

Observed live invite runs show the same high-level pattern:

- `POST https://api.vk.com/method/calls.getAnonymousToken` returns `captcha_required`
- the controlled browser completes the challenge
- browser-owned `POST https://login.vk.com/?act=get_anonym_token` requests occur
- `POST https://api.vk.com/method/calls.getCallPreview` succeeds
- the browser reaches the pre-join page

What remains unknown is the next browser contour after the operator proceeds past preview. Current tooling stops too early to answer that.

## Goals

- Capture sanitized browser-observed post-preview requests and responses in the controlled browser flow.
- Preserve explicit stage ordering so real live evidence can drive the next provider change.
- Keep runtime startup fail-closed until normalized TURN credentials are explicitly observed and parsed.

## Non-Goals

- Synthesizing guessed join/start requests in Go
- Claiming transport-ready parity before post-preview evidence proves it
- Starting TURN, DTLS, or session transport from preview-only or partially observed post-preview state
- Persisting raw cookies, browser profile paths, profile PII, short links, or other live secrets

## Decisions

### Decision: Post-preview observation remains browser-observed, not reconstructed

The operator may interact with the live browser UI after preview, but the provider must only consume requests and responses that were actually observed from that browser context.

### Decision: Preview-only and post-preview contours are separate outcomes

Reaching `calls.getCallPreview` is no longer the final observation boundary. The provider must distinguish:

- preview-only contour
- post-preview contour that still does not yield normalized TURN credentials
- post-preview contour that eventually yields transport-ready credentials

### Decision: Observation plumbing must support ordered multi-stage capture past preview

Current browser observation already captures multiple matching requests, but the provider contract only interprets preview stages. The next change should formalize post-preview stage labels and outcome handling so those results become replayable compatibility evidence.

### Decision: Fail closed remains the default

If post-preview browser observation finishes without transport-ready credentials, the provider must return an explicit provider-stage error and `cmd/tunnel-client` must still exit at `provider_resolve`.

## Risks / Trade-offs

- VK may emit several alternative post-preview contours depending on account state, platform flags, or call ownership.
- Post-preview observation may include more sensitive data than preview, so sanitization scope will grow.
- A single operator confirmation prompt may still be too coarse if the browser needs time to proceed through several UI transitions after preview.

## Validation Plan

- Add sanitized fixtures/tests for at least one post-preview contour outcome.
- Add provider/prompt tests that prove post-preview observation is recorded in order without regressing legacy repeated stage-2 handling or preview-only handling.
- Add `cmd/tunnel-client` coverage proving post-preview non-transport-ready outcomes still fail at `provider_resolve`.
- Run `openspec validate add-vk-post-preview-browser-observation --strict --no-interactive`.
