## Context

The current `vk` provider is a staged HTTP resolver with four fixed steps. A live invite now fails at `vk_calls_get_anonymous_token` because VK returns `error_code=14` and a `redirect_uri` for human verification.
The repository must not implement automated captcha solving or any hidden anti-bot bypass. The safe product change is an operator-assisted continuation path that:

- detects the challenge explicitly
- records a sanitized artifact
- gives the operator a way to complete the VK challenge manually
- retries the blocked stage only after the operator confirms completion

This affects both `cmd/probe` and `cmd/tunnel-client`, because both rely on the same provider resolution path.

## Goals

- Preserve provider-specific logic inside `internal/provider/vk`
- Keep the provider adapter interface stable
- Fail closed by default when no interactive handler is enabled
- Let CLI entrypoints opt into manual challenge continuation without starting transport resources early
- Keep committed fixtures and runtime evidence sanitized and replayable

## Non-Goals

- Automatic captcha solving
- Browser-cookie extraction or hidden VK session scraping
- Changes to TURN/DTLS transport behavior
- Multi-provider interactive UX beyond the minimal generic CLI plumbing needed for `vk`

## Decisions

### Decision: Carry provider-interaction through `context.Context`

The `provider.Adapter` interface remains `Resolve(context.Context, string)`. The `vk` package adds context helpers for an optional interactive challenge handler instead of widening the provider interface across the whole repository.

### Decision: Model captcha as an explicit typed provider challenge

When VK stage 2 returns `error_code=14` with a `redirect_uri`, the resolver produces a typed challenge object with:

- provider/stage identifiers
- a redacted artifact view
- the raw continuation URL for the live operator path only

Without a handler, the resolver returns a provider error with code `captcha_required`.

### Decision: CLI owns the human step

`cmd/probe` and `cmd/tunnel-client` add an explicit opt-in interactive mode for provider challenges.
The CLI handler is responsible for:

- printing short instructions
- optionally opening the challenge URL in the default browser
- waiting for operator confirmation
- retrying the blocked provider stage within a bounded timeout

The provider package does not read from stdin or launch browsers directly.

### Decision: Retry only the blocked VK stage

After operator confirmation, the resolver retries `vk_calls_get_anonymous_token` with the same staged flow state.
It does not silently rerun later transport/session setup, and `tunnel-client` must not bind local transport resources until provider resolution completes.

## Risks / Trade-offs

- VK may require repeated challenges or may bind challenge completion to state we cannot resume; this remains an explicit provider failure.
- Interactive mode is inherently unsuitable for unattended automation; default non-interactive failure behavior is preserved for scripts.
- The CLI needs careful redaction so challenge URLs and session tokens do not leak into persisted artifacts or logs.

## Validation Plan

- Fixture-backed provider tests for `captcha_required` and resumed success
- CLI tests for interactive/non-interactive provider failure handling
- Live smoke validation with `cmd/probe` against a real invite after operator completion
