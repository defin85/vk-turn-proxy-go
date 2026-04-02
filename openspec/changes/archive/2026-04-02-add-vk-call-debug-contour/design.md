## Context

The current Go repository already has a probe entrypoint and a provider registry, but the VK adapter returns `ErrNotImplemented`.
The legacy repository contains a compact, provider-specific `getVkCreds` flow that performs four HTTP exchanges and returns normalized TURN credentials:

1. `POST https://login.vk.ru/?act=get_anonym_token`
2. `POST https://api.vk.ru/method/calls.getAnonymousToken`
3. `POST https://calls.okcdn.ru/fb.do` with `auth.anonymLogin`
4. `POST https://calls.okcdn.ru/fb.do` with `vchat.joinConversationByLink`

This proposal creates a debug contour around that provider flow so the rewrite can collect fixtures and compatibility evidence before porting transport behavior.

## Goals

- Resolve VK invite links into normalized TURN credentials in the Go rewrite without starting TURN or DTLS sessions.
- Record sanitized stage artifacts that can be compared against the legacy behavior and reused in tests.
- Keep provider-specific HTTP flow inside `internal/provider/vk` and keep the probe entrypoint orchestration-only.

## Non-Goals

- Porting the full legacy tunnel client or TURN/DTLS connection loop.
- Adding fallback behavior when VK provider responses drift.
- Generalizing the debug contour into a multi-provider transport abstraction in this change.

## Decisions

- Model VK resolution as an explicit staged state machine in `internal/provider/vk`, where each stage returns typed intermediate data or an explicit error.
- Keep network and parsing logic injectable so compatibility tests can replay sanitized fixtures without live VK dependencies.
- Persist probe artifacts as sanitized structured files in `ProbeConfig.OutputDir`, including stage order, endpoint identifier, status, redacted payload fragments, and normalized credentials summary.
- Normalize invite handling up front: extract the join token from `https://vk.com/call/join/...`, reject empty or malformed input, and feed only the normalized token into stage execution.
- Fail closed if a required field such as access token, anonymous token, TURN username, TURN credential, or TURN URL is missing or malformed.

## Alternatives Considered

- Port the full legacy client first.
  Rejected because it would intertwine provider behavior discovery with transport porting and make compatibility failures harder to isolate.
- Keep using a stub provider until transport work starts.
  Rejected because the repository already treats the legacy implementation as an oracle and needs fixtures before behavior changes.

## Risks / Trade-offs

- Live VK behavior may drift before enough fixtures are captured.
  Mitigation: store sanitized stage artifacts early and make tests run against recorded fixtures.
- Probe artifacts may accidentally capture secrets.
  Mitigation: redact tokens, usernames, credentials, and raw invite data before persisting files.
- The staged resolver may overfit the current legacy flow.
  Mitigation: keep the state machine local to `internal/provider/vk` and specify only normalized outputs in the requirement.

## Migration Plan

1. Capture the legacy VK stage sequence and sanitize the first fixtures.
2. Implement the staged resolver and artifact writer in the Go rewrite.
3. Add compatibility tests that replay the recorded fixtures.
4. Use the resulting debug contour to define the next transport-porting change.

## Open Questions

- Whether the first fixture set should be committed as fully synthetic reconstructions or sanitized captures from a live run.
- Whether operator-facing probe output should default to text only, JSON only, or both.
