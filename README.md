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
- add GUI shells on top of the local client control plane

## Repository layout

```text
cmd/
  clientd/
  probe/
  tunnel-client/
  tunnel-server/
desktop/
  gui_shell/
pkg/
  clientcontrol/
docs/
  agent/
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

## Agent docs

Use these repo-local documents when working through Codex or other agents:

- `docs/agent/index.md`: task routing and the smallest useful doc set
- `docs/agent/architecture-map.md`: subsystem ownership and navigation
- `docs/build-workflows.md`: reproducible local and CI build entrypoints
- `docs/agent/verification.md`: change-specific verification matrix
- `code_review.md`: repository review rubric

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

Build the fast Go-only smoke path:

```bash
go build ./...
```

Build reproducible Go artifact bundles from WSL with:

```bash
make build-go
```

Build the Windows GUI bundle from WSL through the `E:\Projects\vk-turn-proxy-go` mirror with:

```bash
make build-gui-windows
```

The full build workflow contract lives in `docs/build-workflows.md`.
Supported artifact builds derive their human-facing product version from the repo root `version.json`.

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

If VK returns `Captcha needed`, rerun the probe with browser-observed continuation:

```bash
go run ./cmd/probe -provider vk -link 'https://vk.com/call/join/<invite>' -output-dir artifacts -interactive-provider
```

Interactive mode launches a controlled browser session when possible, waits for the operator to complete the challenge and type `continue`, then records either the deterministic repeated stage-2 result or the live browser contour that reaches preview and may continue into post-preview OK stages.
If the live browser contour stops at preview-only state or reaches post-preview without normalized TURN credentials, the probe still fails closed and writes a sanitized artifact instead of claiming TURN-ready parity.
Raw browser cookies, profile paths, and challenge URLs are not persisted in the probe artifact.
If Chromium is not on `PATH`, point the helper at it explicitly with `VK_PROVIDER_BROWSER=/path/to/chromium`.
CI-like environments automatically switch the helper to headless Chromium; override that behavior explicitly with `VK_PROVIDER_BROWSER_HEADLESS=true|false` when needed.

Use the persisted artifact together with the fixture contract in `test/compatibility/vk/` before porting broader legacy client behavior into transport/session code.

`cmd/clientd` now exposes the first local client control plane for GUI shells and embedded hosts.
The contract is versioned, local-only, and exposes:
- profile create/read/delete
- session start/stop/read
- typed challenge continue/cancel resources
- NDJSON event streaming at `/v1/events`
- diagnostics export with per-session metrics and event history

Start the daemon on loopback with:

```bash
go run ./cmd/clientd -listen 127.0.0.1:7777
```

Desktop shells should use the HTTP surface from `cmd/clientd`.
Embedded/mobile hosts should use `pkg/clientcontrol` directly so they share the same profile, session, challenge, and diagnostics semantics without a second contract.

## Desktop GUI shell

The first desktop shell lives in `desktop/gui_shell` and uses Flutter as the canonical GUI stack for Windows, macOS, and Linux.
It talks to the local client control plane on `127.0.0.1:7777`, supervises a compatible `clientd` sidecar, and renders typed profiles, sessions, challenge state, and diagnostics export without requiring terminal-only workflows.

Run the shell locally on Linux with:

```bash
cd desktop/gui_shell
flutter run -d linux
```

Pinned Flutter version and reproducible GUI build entrypoints are documented in `docs/build-workflows.md`.

The shell resolves the local host in this order:
- `GUI_SHELL_CLIENTD_PATH`
- bundled `clientd` next to the app executable
- bundled `Frameworks/clientd` on macOS
- `clientd` from `PATH`
- repo-local `go run ./cmd/clientd -listen 127.0.0.1:7777` during development

If one launched candidate exits early or negotiates as incompatible, the shell disposes it and continues to the next candidate before declaring startup blocked.
If a previously ready host disappears, the shell blocks session actions, reports the failure explicitly, and re-runs compatible host discovery before the operator has to retry manually.

Diagnostics export writes one JSON bundle per session under:
- Linux and macOS: `~/.vk-turn-proxy-go/diagnostics`
- Windows: `%APPDATA%\\vk-turn-proxy-go\\diagnostics`

The desktop banner labels three separate version concepts:
- the local GUI build identity
- the connected host build identity
- the control-plane contract version

Browser challenge continuation stays host-driven in this change.
The GUI triggers the typed challenge continue/cancel operations and surfaces the resulting session events, but it does not embed provider-specific browser flows.
Tray and system-notification behavior are intentionally kept explicit and non-magical for this slice: the shell uses in-app status banners and action buttons rather than background-only runtime control.

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
Internally the CLI now runs through the same client-control runtime host that backs `cmd/clientd`, while keeping the existing operator-facing flags and stderr behavior.
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

Keep a long-lived local harness running for manual desktop-shell or CLI checks with:

```bash
go run ./cmd/turnlab-shell
```

The command prints a ready-to-paste `generic-turn://...` link plus the matching `peer_addr`.
By default, the shell keeps the peer path alive for a 5-minute manual inspection window before enforcing idle cleanup.
Override that window explicitly when needed:

```bash
go run ./cmd/turnlab-shell -peer-idle-timeout 45s
```

For the desktop GUI, create a profile with:
- `Provider`: `generic-turn`
- `Provider link`: the printed `link=...`
- `Peer address`: the printed `peer_addr=...`
- `Local UDP listen`: for example `127.0.0.1:9001`

When the desktop GUI runs on Windows and the harness runs inside WSL, use the cross-host mode instead of the loopback default:

```bash
go run ./cmd/turnlab-shell -windows-gui
```

That mode prints desktop-consumable `link=...` and `peer_addr=...` values backed by a non-loopback IPv4 address.
Advanced runs can override the listener and published addresses explicitly with `-bind-address` and `-advertise-address`, can pin stable published ports with `-turn-port`, `-turn-tcp-port`, and `-peer-port`, and can shorten or extend the manual idle window with `-peer-idle-timeout`.

For a stable remote contour whose firewall rules survive shell restarts, pin the published ports explicitly:

```bash
go run ./cmd/turnlab-shell \
  -bind-address 0.0.0.0 \
  -advertise-address 176.109.104.105 \
  -turn-port 3478 \
  -turn-tcp-port 3478 \
  -peer-port 56000
```

Open matching firewall rules for the protocols you plan to exercise:
- TURN UDP: UDP `3478`
- TURN TCP: TCP `3478`
- DTLS peer: UDP `56000`

Future runtime and integration tests should call `turnlab.Start(ctx, logger)` and consume the returned descriptor:
- `Descriptor.TURNAddress` plus `Descriptor.TURNCredentials` for TURN client setup
- `Descriptor.TURNTCPAddress` when a test needs TURN-over-TCP startup
- `Descriptor.PeerAddress` as the DTLS peer address
- `Descriptor.UpstreamAddress` when a test needs the plain UDP upstream endpoint explicitly
- `GenericTurnLink()` when a test wants to drive `generic-turn` provider startup without hand-building the link
- `Descriptor.GenericTurnTCPLink()` when a test wants a `generic-turn` link anchored to the TCP TURN listener
- `WaitUpstreamPeer(ctx)` plus `InjectUpstream(payload)` when a test needs to assert reply routing independently from the automatic echo path
- `StartWithOptions(... AllocationLifetime ...)` plus `WaitRefreshCount(ctx, n)` when a test needs a short deterministic maintenance window for allocation refresh
- `StartWithOptions(... PeerIdleTimeout ...)` when a test or manual harness run needs a peer idle window different from the default deterministic timeout

CI picks the harness up automatically through the existing `go test ./...` workflow.

Run the first runtime slice locally against the harness-backed deterministic provider through tests:

```bash
go test -v ./internal/session -run TestRunRelayRoundTrip
```

## Local CI and GitHub Actions reproduction

Use the repo-local `Makefile` as the canonical local CI entrypoint:

```bash
make ci
```

`make ci` is the fast local smoke path and runs the same `go test ./...` and `go build ./...` pair as the current CI workflow.

Use `act` through `make` when you want a GitHub-like workflow run through Docker:

```bash
make ci-act
```

Additional `act` helpers:

```bash
make ci-act-dry
make ci-act-verbose
```

The repository includes a repo-local `.actrc` for `act`.
It pins `ubuntu-latest` to a full GitHub-like Ubuntu snapshot because the CI job may exercise browser-backed Chromium tests.
If you need to override the runner image for a one-off run, pass your own variables on the command line, for example:

```bash
act -j test -W .github/workflows/ci.yml -P ubuntu-latest=<your-image>
make ci-act ACT_JOB=test ACT_WORKFLOW=.github/workflows/ci.yml
```

If you want pushes to be gated by the local GitHub-like CI run, opt in to the repo-local hook path:

```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-push
```

The provided `pre-push` hook runs `make ci-act` and is never installed automatically.

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
