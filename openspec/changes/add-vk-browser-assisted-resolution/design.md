## Context

The current `add-vk-captcha-interactive-resolution` change added challenge detection, operator prompts, and retry of `vk_calls_get_anonymous_token`.
Live validation on April 4, 2026 showed that this is insufficient: after the operator solves the captcha in a regular browser and the CLI retries stage 2, VK returns the same captcha again.

The most likely explanation is that successful challenge completion is bound to browser session state that is absent from the resolver's plain HTTP client.
The repository must not implement automated captcha solving or hidden anti-bot bypass. The next safe step is a browser-assisted provider flow where:

- the operator solves the challenge in a browser session that the tool owns or can query explicitly
- the provider continues stage 2 using that same browser-backed session context
- default non-interactive behavior remains unchanged and fail-closed

## Goals

- Preserve provider-specific VK logic inside `internal/provider/vk`
- Avoid scraping cookies from the user's default browser profile
- Keep transport startup blocked until provider resolution fully succeeds
- Reuse the existing `-interactive-provider` operator intent instead of introducing a second overlapping UX flag unless implementation constraints force it
- Keep artifacts and logs sanitized even when browser-assisted mode is used

## Non-Goals

- Automatic captcha solving
- General browser automation for non-VK providers
- Silent fallback from browser-assisted mode to insecure or hidden session reuse
- Changes to TURN, DTLS, or forwarding behavior

## Decisions

### Decision: Use a controlled browser session for VK captcha-gated stage 2

When the VK provider detects `captcha_required` and interactive handling is enabled, the CLI must be able to launch or attach to a controlled browser session for the operator to complete the challenge.
The provider then replays `vk_calls_get_anonymous_token` using the resulting browser-backed session state rather than the original plain HTTP client alone.

### Decision: Keep browser/session plumbing outside transport code

Browser launch, session lifecycle, and operator prompts remain runtime concerns owned by `cmd/probe` and `cmd/tunnel-client` plus a narrow helper package.
`internal/provider/vk` consumes an explicit browser-assisted continuation capability through context or a typed helper interface, not by reaching into CLI concerns directly.

### Decision: Fail closed if browser-assisted continuation is unavailable

If the browser cannot be started, attached, or queried for the needed session state, provider resolution fails at `provider_resolve` with an explicit error.
The runtime must not silently retry with the old HTTP-only path once VK has demonstrated that browser state is required.

### Decision: Preserve the current challenge artifact contract and extend it

The existing `captcha_required` artifact remains valid.
Browser-assisted success adds explicit evidence that:

- the initial stage-2 attempt returned `captcha_required`
- the operator completed a browser challenge
- the resumed stage-2 attempt used browser-assisted continuation and then advanced to stages 3 and 4

## Alternatives Considered

### Plain retry after manual browser step

Rejected. Live evidence already showed repeated captcha on two different invites after manual confirmation.

### Import cookies from the user's default browser profile

Rejected. This is brittle, platform-specific, higher risk for secret leakage, and does not give the tool explicit ownership of the session used for the challenge.

### Automatic captcha solving

Rejected. Out of scope and unacceptable for both safety and product reasons.

## Risks / Trade-offs

- A browser automation dependency or browser-session integration increases operational complexity.
- VK may still gate stage 2 in ways that require more than browser cookies alone; the change must surface that explicitly rather than overclaiming success.
- Browser-assisted mode may be harder to test in CI, so deterministic fixtures plus documented manual smoke checks are required.

## Validation Plan

- Provider-level fixtures for `captcha_required`, browser-assisted continuation success, and browser-assisted continuation failure
- CLI tests that ensure browser-assisted provider resolution happens before any transport resources are created
- Manual live probe verification with a fresh invite after implementation
