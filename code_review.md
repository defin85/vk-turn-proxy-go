# Code Review Guide

Use this rubric when the task is to review code, audit a diff, or compare implementation against a plan/spec.

## Review goals

- Catch behavior regressions and spec drift first.
- Check that verification and compatibility evidence actually cover the changed behavior.
- Protect the package boundaries between provider, transport, session, and runtime concerns.
- Keep operator-facing behavior, observability, and sanitization aligned with the documented contract.

## Findings-first format

- Report findings before summaries when issues exist.
- Order findings by severity.
- Each finding should include the affected path/line, the behavior at risk, why it matters, and the missing test/spec/evidence when relevant.
- Do not use task lists, TODOs, or proposal text as proof that behavior is implemented.

## Review checklist

### Contract and scope

- Does the change match the relevant `openspec/specs/*/spec.md` contract?
- Does it avoid claiming behavior that is not implemented or not evidenced yet?

### Verification and evidence

- Were the smallest relevant checks run?
- If the change affects wire behavior or compatibility, were fixtures/replay tests/docs updated together?
- If tests are missing, is the gap called out explicitly?

### Boundaries

- Provider-specific logic stays in `internal/provider/...`.
- TURN/DTLS/UDP mechanics stay provider-agnostic.
- Runtime/config/logging/metrics concerns stay out of transport packages.

### Failure handling

- Provider failures remain explicit and fail closed.
- Stage-aware errors, artifacts, and operator-facing messages stay coherent.

### Operator surface

- Flag behavior in `cmd/*`, runtime docs, and tests remains aligned.
- Metrics/log field names and stage names stay consistent with `docs/runtime-observability.md`.

### Security and sanitization

- No raw invite tokens, TURN credentials, cookies, challenge URLs, or browser profile paths leak into logs, fixtures, or artifacts.

### Maintainability

- Packages and files remain focused.
- New abstractions are justified by real ownership boundaries, not speculation.

## Verification note

Reviews should state which checks were run, which were not run, and any remaining risk from that gap.
