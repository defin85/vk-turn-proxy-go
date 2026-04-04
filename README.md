# vk-turn-proxy-go

Canonical Go repository for a maintainable TURN/DTLS tunnel product.

This repository is a clean-room successor to the working prototype in `/home/egor/code/vk-turn-proxy`.
The prototype remains the compatibility oracle until equivalent behavior is covered by tests here.

## Status

Phase 0 is complete in this repository:
- canonical module and package layout
- working modular server baseline
- client and probe entrypoints with stable contracts
- ADR and provider matrix for future work
- unit-test baseline for config and provider registry

Phase 1 is next:
- port the legacy client behavior behind provider and transport boundaries
- add compatibility tests against the legacy Go implementation
- add runtime observability

## Repository layout

```text
cmd/
  probe/
  tunnel-client/
  tunnel-server/
docs/
  adr/
internal/
  config/
  observe/
  provider/
    genericturn/
    vk/
  providerprompt/
  session/
  transport/
  tunnelserver/
test/
  compatibility/
```

## Design contract

Inputs:
- provider link and provider type
- local UDP listen address
- remote peer/server address
- transport policy such as DTLS on or off and TURN UDP on or off

Outputs:
- stable tunnel session lifecycle
- structured logs with session identifiers
- explicit provider and transport failures

Invariants:
- provider logic does not leak into transport packages
- transport code stays compatible with reference behavior where declared
- behavior changes require tests or an explicit compatibility note

## Quick start

Build all binaries:

```bash
go build ./...
```

Run the server baseline:

```bash
go run ./cmd/tunnel-server -connect 127.0.0.1:51820
```

List available providers in probe:

```bash
go run ./cmd/probe -list-providers
```

Run the deterministic lab provider:

```bash
go run ./cmd/probe -provider generic-turn -link 'generic-turn://user:pass@turn.example.test:3478' -output-dir artifacts
```

Successful runs print the normalized TURN address and write a sanitized artifact to `artifacts/generic-turn/probe-artifact.json`.

Run the VK provider debug contour:

```bash
go run ./cmd/probe -provider vk -link 'https://vk.com/call/join/<invite>' -output-dir artifacts
```

Successful runs print a normalized summary including the resolved TURN address, stage count, and artifact path.
The probe writes a sanitized JSON artifact to `artifacts/vk/probe-artifact.json`.
Provider-stage failures also persist a sanitized artifact before the command exits non-zero.

The probe remains provider-only by design:
- it normalizes the invite
- it resolves staged VK/OK credentials
- it does not start TURN, DTLS, or session transport loops

If VK returns `Captcha needed`, rerun the probe with browser-observed stage-2 continuation:

```bash
go run ./cmd/probe -provider vk -link 'https://vk.com/call/join/<invite>' -output-dir artifacts -interactive-provider
```

Interactive mode launches a controlled browser session when possible, waits for the operator to complete the challenge and type `continue`, then lets the browser complete the native VK captcha continuation flow and imports only the observed repeated stage-2 result back into the provider flow.
Raw browser cookies, profile paths, and challenge URLs are not persisted in the probe artifact.
If Chromium is not on `PATH`, point the helper at it explicitly with `VK_PROVIDER_BROWSER=/path/to/chromium`.

Use the persisted artifact together with the fixture contract in `test/compatibility/vk/` before porting broader legacy client behavior into transport/session code.

`cmd/tunnel-client` now runs the supported supervised client runtime matrix after provider resolution.
Supported startup policy for this slice:
- `connections >= 1` through supervised transport workers sharing one local UDP listener
- local listener stays UDP
- `dtls=true|false`
- `mode=auto|udp|tcp` where `auto` normalizes to the provider-default UDP TURN path
- empty `bind-interface` or a literal local IP for outbound TURN setup
- round-robin local datagram dispatch across ready workers
- "most recent local sender" reply routing within each worker; stable multi-peer routing across a supervised session is still not claimed

Rejected combinations fail closed before provider resolution:
- non-IP `bind-interface` values such as interface names

Lifecycle policy for supervised sessions:
- worker startup failures before readiness fail the session with the worker's transport stage
- runtime worker failures after readiness are restarted with deterministic backoff
- restart-budget exhaustion fails the session with `session_supervision`

When startup fails after policy validation, the command reports a stage-aware error such as `provider_resolve`, `turn_dial`, `turn_allocate`, `peer_setup`, `dtls_handshake`, or `session_supervision`.
`-turn` and `-port` overrides remain supported and are applied after provider credential resolution.
If the selected provider returns an interactive VK captcha challenge, start the client with `-interactive-provider` so provider resolution can pause for a controlled browser step before any local listener or TURN transport is started.
Long-lived reliability is currently evidenced by deterministic TURN allocation-refresh coverage in `turnlab` and runtime integration tests; the repository still does not claim live mobile-network or NAT parity from that alone.

Client and server runtimes now expose an optional Prometheus-style metrics surface through `-metrics-listen <addr>`.
The first metric set covers session starts, session failures, startup-stage failures, transport-stage failures, active workers, and forwarded packets/bytes.
Structured runtime events use stable fields such as `event`, `runtime`, `session_id`, `provider`, `turn_mode`, `peer_mode`, `stage`, and `result`.
The observability contract and operator workflow are documented in `docs/runtime-observability.md`.

## TURN lab harness

The repository now includes a reusable local TURN lab harness in `test/turnlab`.
It starts three real components under one fixture:
- an in-process TURN server with static credentials
- UDP and TCP TURN listeners over the same relay fabric
- the DTLS tunnel server from `internal/tunnelserver`
- a UDP echo target behind the tunnel server

Run the harness smoke test locally with:

```bash
go test -v ./test/turnlab -run TestHarnessRelayRoundTrip
```

Future runtime and integration tests should call `turnlab.Start(ctx, logger)` and consume the returned descriptor:
- `Descriptor.TURNAddress` plus `Descriptor.TURNCredentials` for TURN client setup
- `Descriptor.TURNTCPAddress` when a test needs TURN-over-TCP startup
- `Descriptor.PeerAddress` as the DTLS peer address
- `Descriptor.UpstreamAddress` when a test needs the plain UDP upstream endpoint explicitly
- `GenericTurnLink()` when a test wants to drive `generic-turn` provider startup without hand-building the link
- `Descriptor.GenericTurnTCPLink()` when a test wants a `generic-turn` link anchored to the TCP TURN listener
- `WaitUpstreamPeer(ctx)` plus `InjectUpstream(payload)` when a test needs to assert reply routing independently from the automatic echo path
- `StartWithOptions(... AllocationLifetime ...)` plus `WaitRefreshCount(ctx, n)` when a test needs a short deterministic maintenance window for allocation refresh

CI picks the harness up automatically through the existing `go test ./...` workflow.

Run the first runtime slice locally against the harness-backed deterministic provider through tests:

```bash
go test -v ./internal/session -run TestRunRelayRoundTrip
```

## Planning and tracking

Use OpenSpec for behavior and architecture changes:

```bash
openspec list
openspec list --specs
openspec validate --strict --no-interactive --all
```

Project-specific OpenSpec conventions live in `openspec/project.md`. The general workflow for proposals and implementation handoff lives in `openspec/AGENTS.md`.

Use Beads for task tracking instead of markdown TODO lists:

```bash
bd ready
bd create "Describe the task" --type task --priority 2
bd close <id>
```

This repository was initialized without git hooks. If you want Beads to auto-inject workflow context locally, install them explicitly with `bd hooks install`.

## Assumptions

- Module path is currently `github.com/defin85/vk-turn-proxy-go`.
- The repository directory is `/home/egor/code/vk-turn-proxy-go`.
- Provider adapters are added incrementally; `vk` and `generic-turn` resolve credentials today.
