## Context

The repository currently assumes that interactive VK recovery after captcha is still anchored on a repeated `vk_calls_get_anonymous_token` request.

Live HAR evidence from April 4, 2026 contradicts that assumption for at least one real invite flow:

- `GET /call/join/...`
- `GET /challenge.html?...`
- `GET /call/join/...`
- `POST https://login.vk.com/?act=get_anonym_token`
- `POST https://api.vk.com/method/calls.getSettings`
- `POST https://login.vk.com/?act=get_anonym_token` with `token_type=messages`
- `POST https://api.vk.com/method/calls.getCallPreview`

The browser then reaches the pre-join page with the name input. No repeated `calls.getAnonymousToken` request appears in that trace.

## Goals

- Model the live post-challenge browser contour explicitly instead of forcing it into the legacy stage-2 replay shape.
- Capture sanitized, structured evidence for the live browser contour.
- Keep provider and runtime behavior fail-closed while the live contour only reaches pre-join preview state.
- Preserve deterministic legacy fixtures as a separate contour for parser and compatibility work.

## Non-Goals

- Automatic captcha solving or anti-bot bypass
- Claiming full live TURN parity before evidence shows where live TURN credentials are produced
- Moving transport concerns into provider code
- Persisting raw HAR files, raw browser tokens, cookies, or challenge URLs

## Decisions

### Decision: Split legacy staged contour from live browser preview contour

The legacy `getVkCreds`-style staged contour remains valuable as deterministic compatibility evidence, but it no longer defines the live browser flow after captcha. The rewrite must represent these as separate contours.

### Decision: The live browser contour is browser-observed, not reconstructed in Go

The provider may observe browser requests and responses for the live contour, but it must not synthesize guessed browser payloads in Go and claim that as live parity.

### Decision: Preview-only state is an explicit provider outcome

If the live browser contour reaches pre-join preview state without yielding TURN credentials, the provider must return an explicit stage-aware provider error or structured preview-only result. `cmd/tunnel-client` must not start transport from that state.

### Decision: Sanitized evidence must anchor the new contour

The new contour must be backed by committed sanitized fixtures and tests so the repository stops overfitting to a stale assumption about repeated `calls.getAnonymousToken`.

## Alternatives Considered

### Keep waiting for repeated `calls.getAnonymousToken`

Rejected. Live HAR evidence already shows a successful browser transition to pre-join preview without that request.

### Replace the whole provider with browser automation

Rejected. The repository still needs typed provider logic, deterministic fixtures, and fail-closed runtime startup.

## Risks / Trade-offs

- VK may have multiple live contours, not just one browser preview path.
- The browser contour may still diverge further after the pre-join page, so initial implementation should avoid promising TURN credential parity too early.
- The provider contract becomes more complex because it now has to distinguish deterministic legacy evidence from live browser evidence.

## Validation Plan

- Add sanitized fixtures/tests for the browser preview contour and explicit preview-only failure.
- Add provider/prompt tests proving the rewrite no longer waits for repeated `calls.getAnonymousToken` when the live browser contour does not use it.
- Add `cmd/tunnel-client` coverage proving transport still does not start from preview-only provider state.
- Run `openspec validate update-vk-live-browser-preview-contour --strict --no-interactive`.
