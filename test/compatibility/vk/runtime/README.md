# VK Runtime Compatibility Evidence

## Scope

This contract covers the supported VK-backed client runtime slice introduced by
`03-add-tunnel-client-runtime`.

It is intentionally limited to:

- `connections=1`
- `dtls=true`
- `mode=udp|auto`
- empty `bind-interface`
- one active local UDP peer per session for reply routing

It explicitly excludes:

- `mode=tcp`
- `dtls=false`
- non-empty `bind-interface`
- multi-connection supervision
- mobile rebinding and broader legacy parity claims

## Evidence layout

Runtime compatibility evidence lives under:

```text
test/compatibility/vk/runtime/
  README.md
  evidence.schema.json
  assets_test.go
  examples/
    vk_runtime_success_v1.template.json
    vk_runtime_failure_v1.template.json
  fixtures/
    .gitkeep
```

`examples/` contains schema-valid templates only.
They define the required shape and redaction rules, but they are not acceptance
evidence.

Real captured evidence belongs in `fixtures/` with the same `scenario_id`
values and without the `.template` suffix.

## First scenarios

### `vk_runtime_success_v1`

Supported-slice success case for:

- VK provider resolution
- one TURN allocation
- one DTLS-backed relay session
- successful UDP round-trip through the configured peer

Expected compatibility claim:

- the legacy client succeeds for the same redacted scenario
- the rewrite succeeds for the same redacted scenario
- the rewrite preserves the supported-slice startup order and forwarding result

### `vk_runtime_failure_v1`

Supported-slice explicit runtime failure case for:

- VK provider resolution succeeds
- runtime startup fails deterministically after provider resolution
- the rewrite surfaces the expected stage-aware error

Expected compatibility claim:

- the failure is recorded explicitly instead of being inferred from logs
- any intentional deviation from legacy semantics is written into
  `deviations[]`

## Asset format

Every runtime evidence asset must satisfy
`test/compatibility/vk/runtime/evidence.schema.json`.

Required top-level fields:

- `scenario_id`
- `provider`
- `kind`
- `source`
- `slice`
- `input`
- `legacy`
- `rewrite`
- `deviations`

`source.kind` values:

- `template`
- `manual_live`
- `fixture_replay`

`kind` values:

- `runtime_success`
- `runtime_failure`

## Redaction rules

- Replace the raw invite everywhere with
  `https://vk.com/call/join/<redacted:vk-join-token>`.
- Replace raw TURN username and password with
  `<redacted:turn-username>` and `<redacted:turn-password>`.
- Replace provider cookies, session keys, and any bearer-like values with
  descriptive `<redacted:...>` placeholders.
- If a peer endpoint must not be committed, replace it with
  `<redacted:peer-addr>`.
- Keep exit codes, result kind, stage names, and supported-slice policy values
  intact.

## Intentional deviations versus legacy

The rewrite currently does not claim compatibility for:

- `mode=tcp`
- `dtls=false`
- non-empty `bind-interface`
- `connections > 1`
- multi-peer reply demultiplexing beyond the most recent local sender

If a live VK run exposes any additional supported-slice deviation, record it in
`deviations[]` instead of silently accepting drift.

## Capture workflow

1. Prepare a local peer target for the supported slice and note its redacted
   description.
2. Run the legacy oracle against a live VK invite and capture only redacted
   outcomes.
3. Run `go run ./cmd/tunnel-client ...` with the same supported-slice policy.
4. Copy the matching template from `examples/` into `fixtures/`.
5. Replace template placeholders with redacted observed values.
6. Record any intentional legacy deviation in `deviations[]`.
7. Run `go test ./test/compatibility/vk/runtime -run TestRuntimeEvidenceAssets`.

## Refresh workflow

Refresh the runtime evidence set whenever one of the following changes:

- the supported policy matrix for the VK-backed runtime slice
- startup stage taxonomy
- forwarding semantics for the supported slice
- a change claims new parity or a new intentional deviation versus legacy

Do not update the recorded evidence without rerunning both the rewrite and the
legacy oracle for the affected scenario.
