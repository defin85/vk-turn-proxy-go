# VK Call Debug Contour Compatibility Contract

## Scope

This contract covers the provider-only VK flow mirrored from the legacy `getVkCreds` implementation in `/home/egor/code/vk-turn-proxy/client/main.go`.
It is intentionally limited to:

- invite normalization from `https://vk.com/call/join/...`
- staged VK/OK HTTP resolution
- normalized TURN credential output
- explicit provider-stage failures

It explicitly excludes TURN allocation, DTLS handshake, session orchestration, and UDP forwarding.

## Legacy stage contract

The compatibility baseline is the four-stage sequence already present in the legacy client:

| Stage | Endpoint ID | Legacy endpoint | Required field(s) extracted |
| --- | --- | --- | --- |
| 1 | `vk_login_anonym_token` | `POST https://login.vk.ru/?act=get_anonym_token` | `data.access_token` |
| 2 | `vk_calls_get_anonymous_token` | `POST https://api.vk.ru/method/calls.getAnonymousToken` | `response.token` |
| 3 | `ok_anonym_login` | `POST https://calls.okcdn.ru/fb.do` with `auth.anonymLogin` | `session_key` |
| 4 | `ok_join_conversation_by_link` | `POST https://calls.okcdn.ru/fb.do` with `vchat.joinConversationByLink` | `turn_server.username`, `turn_server.credential`, `turn_server.urls[0]` |

The rewrite must preserve this stage order for the initial debug contour.
If a required field is missing or malformed, the provider must fail at the stage where the field becomes unavailable.

## First scenarios

### `vk_call_debug_success_v1`

Input contract:

- provider: `vk`
- invite URL is stored only in redacted form: `https://vk.com/call/join/<redacted:vk-join-token>`
- normalized join token is stored only in redacted form: `<redacted:vk-join-token>`

Expected behavior:

- the probe executes stages 1 through 4 in order
- each stage returns a successful HTTP response fixture
- stage 4 yields a TURN URL whose normalized address is `host:port`
- normalized output contains:
  - `username_redacted`
  - `password_redacted`
  - `address`
- `address` omits the `turn:` or `turns:` prefix
- `address` omits any query string suffix such as `?transport=udp`

### `vk_call_debug_stage4_missing_turn_url_v1`

Input contract:

- same redacted invite handling as the success scenario
- stages 1 through 3 succeed
- stage 4 omits `turn_server.urls[0]` or provides a malformed TURN URL

Expected behavior:

- the provider returns an explicit provider error
- the reported failing stage is `ok_join_conversation_by_link`
- no fallback URL or alternative provider behavior is attempted
- sanitized artifacts still contain stages 1 through 4, including the failing stage payload

## Fixture layout

The fixture directory for this contract is:

```text
test/compatibility/vk/
  fixture.schema.json
  fixtures/
    .gitkeep
    vk_call_debug_success_v1.json
    vk_call_debug_stage4_missing_turn_url_v1.json
```

Task `1.2` in the OpenSpec change is responsible for creating the two JSON fixtures above.
Task `1.1` defines their contract only.

The first committed fixture set is a sanitized reconstruction of the legacy `getVkCreds` stage flow.
It is sufficient for deterministic parser and normalization tests even before a live-capture workflow is added.

## Sanitization rules

Fixtures and probe artifacts must preserve structure while removing live secrets.

- Replace the raw invite token everywhere with `<redacted:vk-join-token>`.
- Replace stage tokens with descriptive placeholders such as `<redacted:vk-access-token-1>`, `<redacted:vk-anonym-token>`, and `<redacted:ok-session-key>`.
- Replace TURN username and password with `<redacted:turn-username>` and `<redacted:turn-password>`.
- Do not persist raw cookies, authorization headers, IP-bound session identifiers, or unredacted request bodies.
- Preserve endpoint IDs, HTTP status codes, field names, stage ordering, and normalized TURN address semantics.
- If a live TURN host must not be committed, replace it with a synthetic host that preserves normalization behavior, for example `turn.example.test:3478`.

## Required fixture fields

Every VK compatibility fixture must satisfy `test/compatibility/vk/fixture.schema.json` and include:

- `scenario_id`
- `provider`
- `legacy_source`
- `input`
- `stages`
- `expected`

Each `stages[]` item must include:

- `name`
- `endpoint_id`
- `request`
- `response`
- `outcome`

The `expected` block must describe either:

- a successful normalized resolution with redacted credentials and normalized address
- or an explicit provider error with the failing stage and machine-readable error code

## Notes for implementation

- The rewrite should model stage parsing as typed provider logic inside `internal/provider/vk`.
- `cmd/probe` may write richer artifacts than the fixture contract, but committed fixtures must remain replayable and sanitized.
- Compatibility tests should use the fixture `scenario_id` values as stable test case names.

## Running the contour

Use the probe to execute the current VK provider-only debug contour:

```bash
go run ./cmd/probe -provider vk -link 'https://vk.com/call/join/<invite>' -output-dir artifacts
```

Expected operator workflow:

1. Run the probe with a VK invite.
2. Inspect the one-line summary on stdout for `turn_addr`, `stages`, and `artifact`.
3. Inspect `artifacts/vk/probe-artifact.json` for the sanitized stage trace.
4. Compare the resulting stage sequence and normalized address semantics with the committed fixtures in `test/compatibility/vk/fixtures/`.

This contour is the bridge between fixture-driven provider parity work and the next transport-porting change.
Do not use it as evidence that TURN allocation, DTLS handshake, or end-to-end tunneling is already compatible.
