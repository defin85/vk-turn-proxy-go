## Context

The repository already supports:

- operator-confirmed interactive captcha handling
- controlled-browser execution for provider-owned stage retries
- browser-owned execution of a synthetic repeated VK stage 2 request

Live traces showed the remaining gap precisely:

- the browser first receives `captcha_required` from `vk_calls_get_anonymous_token`
- after the operator completes captcha, the browser runs `captchaNotRobot.settings`, `captchaNotRobot.componentDone`, `captchaNotRobot.check`, and `captchaNotRobot.endSession`
- only then does the browser send a second `calls.getAnonymousToken` request with additional captcha continuation fields
- the current rewrite does not observe or reuse that native browser-owned continuation result

The next step must remain provider-scoped and must not claim captcha solving or anti-bot bypass.

## Goals

- Let the controlled browser own the native VK captcha continuation chain
- Observe the repeated `vk_calls_get_anonymous_token` response that follows that native chain
- Return only the minimal structured stage-2 result needed for stages 3 and 4
- Preserve explicit provider-stage failures and sanitized artifacts
- Keep `cmd/tunnel-client` fail-closed until provider resolution is fully complete

## Non-Goals

- Automatic captcha solving or anti-bot bypass
- Synthesizing or replaying browser-only captcha continuation payloads directly from Go as the claimed success path
- Moving stages 1, 3, or 4 into the browser unless new evidence proves it is required
- Persisting raw browser profiles, cookies, session tokens, success tokens, captcha payloads, or unredacted HAR captures

## Decisions

### Decision: The browser owns the native captcha continuation chain

After the operator solves captcha, the controlled browser remains the execution owner for the native continuation chain.
The rewrite must not claim success by posting a guessed or reconstructed continuation payload from Go alone.

### Decision: Observe the repeated stage-2 result, not the browser internals

The provider prompt layer may observe network responses or other browser-native completion signals needed to identify the repeated successful `calls.getAnonymousToken` response.
Only a structured stage-2 result may cross back into provider logic.
Raw browser cookies, `session_token`, `success_token`, and similar browser-owned payload details must not be persisted in artifacts.

### Decision: Fail closed if the browser never yields a usable repeated stage 2 result

If the native browser continuation chain completes but no usable repeated `vk_calls_get_anonymous_token` result is observed, or if that observed result is still challenge-gated, provider resolution must fail explicitly at `vk_calls_get_anonymous_token`.

### Decision: Treat live HAR traces as diagnostic evidence only

Live HAR traces are allowed as transient operator diagnostics to discover the native browser flow, but they are not committed evidence artifacts.
Committed evidence must stay sanitized and replayable.

## Alternatives Considered

### Reconstruct the captcha continuation payload in Go

Rejected.
This would move the implementation toward synthetic anti-bot replay rather than browser-observed native continuation, and the live browser trace already shows additional browser-owned context beyond plain form fields.

### Keep only the current browser-owned synthetic stage-2 request

Rejected.
Live evidence shows that replaying a plain repeated stage 2 from the browser context is still insufficient.

## Risks / Trade-offs

- Browser network observation may become brittle if VK changes its frontend flow or endpoint names.
- Sanitizing browser-derived artifacts is more delicate because continuation payloads include sensitive fields such as `session_token`, `success_token`, and invite-specific request parameters.
- The controlled browser may keep progressing to later VK/OK requests quickly, so response capture must remain scoped to the repeated stage 2 and avoid overclaiming later-stage browser ownership.

## Validation Plan

- Fixture-backed tests for browser-observed stage-2 success and explicit failure
- Probe and tunnel-client tests proving that transport still does not start before browser-observed provider continuation succeeds
- Sanitization tests proving that artifacts redact `success_token`, `session_token`, captcha continuation fields, and request-param secret values
- `openspec validate add-vk-browser-observed-stage2-continuation --strict --no-interactive`
