# VK Runtime Compatibility Evidence

## Scope

This contract covers the supported VK-backed client runtime slice after
`05-expand-transport-policy-matrix`.

It currently records replayable evidence for:

- `connections=1`
- `dtls=true|false`
- `mode=auto|udp|tcp`
- empty `bind-interface` or a literal local IP
- one active local UDP peer per session for reply routing

It explicitly excludes:

- non-IP `bind-interface` values such as interface names
- mobile rebinding and broader legacy parity claims

The runtime now also supports supervised sessions with `connections > 1`, but
that behavior is not yet anchored by committed VK replay assets in this
directory. Treat multi-worker supervision as implemented runtime behavior with
remaining provider-compatibility evidence work.

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
    vk_runtime_tcp_dtls_success_v1.template.json
    vk_runtime_udp_plain_success_v1.template.json
    vk_runtime_tcp_plain_success_v1.template.json
    vk_runtime_bind_target_success_v1.template.json
    vk_runtime_auto_plain_success_v1.template.json
    vk_runtime_auto_bind_success_v1.template.json
  fixtures/
    vk_runtime_success_v1.json
    vk_runtime_failure_v1.json
    vk_runtime_tcp_dtls_success_v1.json
    vk_runtime_udp_plain_success_v1.json
    vk_runtime_tcp_plain_success_v1.json
    vk_runtime_bind_target_success_v1.json
    vk_runtime_auto_plain_success_v1.json
    vk_runtime_auto_bind_success_v1.json
```

`examples/` contains schema-valid templates only.
They define the required shape and redaction rules, but they are not acceptance
evidence.

Real captured evidence belongs in `fixtures/` with the same `scenario_id`
values and without the `.template` suffix.

The committed baseline uses `source.kind=fixture_replay`.
That means each asset is backed by replayable committed inputs:

- provider resolution is anchored by the sanitized VK provider fixture set in
  `test/compatibility/vk/fixtures/`
- rewrite runtime behavior is anchored by deterministic `turnlab` integration
  tests
- legacy runtime expectations are recorded as oracle notes with source
  references, not as a CI replay of a live VK session

`manual_live` evidence remains allowed for future refreshes, but it is not
required for the first committed baseline.

## First scenarios

### `vk_runtime_success_v1`

Supported-slice success case for:

- VK provider resolution
- one TURN allocation
- one DTLS-backed relay session
- successful UDP round-trip through the configured peer on the provider-default transport path

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

### `vk_runtime_tcp_dtls_success_v1`

Supported-slice success case for:

- VK provider resolution
- TCP between the client and the TURN server
- one DTLS-backed relay session
- successful UDP round-trip through the configured peer

### `vk_runtime_udp_plain_success_v1`

Supported-slice success case for:

- VK provider resolution
- UDP between the client and the TURN server
- plain datagram relay without DTLS
- successful UDP round-trip through the configured upstream peer

### `vk_runtime_tcp_plain_success_v1`

Supported-slice success case for:

- VK provider resolution
- TCP between the client and the TURN server
- plain datagram relay without DTLS
- successful UDP round-trip through the configured upstream peer

### `vk_runtime_bind_target_success_v1`

Supported-slice success case for:

- VK provider resolution
- literal local IP `bind-interface`
- successful runtime startup and forwarding on the rewrite path
- explicit legacy deviation recording because the legacy oracle has no equivalent committed flag

### `vk_runtime_auto_plain_success_v1`

Supported-slice success case for:

- VK provider resolution
- `mode=auto` normalization to the provider-default UDP TURN path
- plain datagram relay without DTLS
- successful UDP round-trip through the configured upstream peer

### `vk_runtime_auto_bind_success_v1`

Supported-slice success case for:

- VK provider resolution
- `mode=auto` normalization to the provider-default UDP TURN path
- literal local IP `bind-interface`
- successful runtime startup and forwarding on the rewrite path with verified TURN source IP

## Asset format

Every runtime evidence asset must satisfy
`test/compatibility/vk/runtime/evidence.schema.json`.

Required top-level fields:

- `scenario_id`
- `provider`
- `kind`
- `source`
- `replay`
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

`replay.provider_fixture`:

- points to the sanitized VK provider fixture that drives staged HTTP resolution
  for the runtime replay

`replay.expect_turn_base_ip`:

- is required for fixture assets that claim a literal-IP `bind-interface`
- records the exact TURN source IP that replay verification must observe

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

For the committed `fixture_replay` baseline, runtime targets are symbolic:

- `<runtime:turnlab-host>`
- `<runtime:turnlab-port>`
- `<runtime:turnlab-tcp-host>`
- `<runtime:turnlab-tcp-port>`
- `<runtime:turnlab-peer>`
- `<runtime:turnlab-upstream>`
- `<runtime:plain-udp-peer>`

Verification tooling materializes those placeholders into deterministic local
resources at test time.

## Intentional deviations versus legacy

The rewrite currently does not claim compatibility for:

- non-IP `bind-interface`
- VK-backed evidence for `connections > 1`
- multi-peer reply demultiplexing beyond the most recent local sender

If a live VK run exposes any additional supported-slice deviation, record it in
`deviations[]` instead of silently accepting drift.

## Replay baseline workflow

1. Start from the matching template in `examples/`.
2. Anchor provider resolution to the sanitized VK fixture contract in
   `test/compatibility/vk/fixtures/`.
3. Encode runtime targets with the supported symbolic placeholders instead of
   committing ephemeral local ports.
4. Anchor rewrite runtime behavior to deterministic tests for the same
   supported-slice contract, including the concrete transport mode and relay
   mode for the scenario.
5. Record the legacy runtime expectation with source references and clear notes
   when CI cannot replay the live VK session directly.
6. Write the final asset into `fixtures/` with `source.kind=fixture_replay`.
7. Record any intentional legacy deviation in `deviations[]`.
8. Run `go test ./test/compatibility/vk/runtime -run 'TestRuntimeEvidence(Assets|Replay)'`.

## Optional manual live refresh

When a live invite is available and the supported slice changes materially:

1. Run the legacy oracle against the live VK invite and capture only redacted
   outcomes.
2. Run `go run ./cmd/tunnel-client ...` with the same supported-slice policy.
3. Replace the replay notes with the observed redacted outcomes.
4. Switch `source.kind` from `fixture_replay` to `manual_live`.
5. Keep the same `scenario_id` so replay and live evidence remain comparable.

## Refresh workflow

Refresh the runtime evidence set whenever one of the following changes:

- the supported policy matrix for the VK-backed runtime slice
- startup stage taxonomy
- forwarding semantics for the supported slice
- a change claims new parity or a new intentional deviation versus legacy

Do not update the recorded evidence without rerunning both the rewrite and the
legacy oracle for the affected scenario when the asset is `manual_live`.
For `fixture_replay` assets, rerun the referenced provider and runtime tests and
refresh the legacy-oracle notes if the supported slice meaning changes.
