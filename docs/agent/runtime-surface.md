# Runtime Surface

Use this document when you need the operator/runtime picture without reading the full `README.md`.
It is the concise first-pass view for Codex and other repository-local agents.

## Product slice today

- `vk-turn-proxy-go` is the canonical Go rewrite for the TURN/DTLS tunnel product.
- The legacy repository `/home/egor/code/vk-turn-proxy` remains the compatibility oracle until equivalent coverage exists here.
- Current shipped slices cover provider resolution for `vk` and `generic-turn`, the local client control plane, runtime observability, the turnlab harness, and desktop/mobile Flutter shells.
- The first packaged Windows system-tunnel ready path is now repo-owned through `windows_wintun`; use `docs/windows-desktop-wg-poc.md` for the verified operator and VMware execution-cell runbook.
- The local control plane now exposes typed runtime execution planning so current overlay startup, future packaged `wireguard_native` plans, and later experimental carriers stay explicitly separated.
- Provider logic stays in `internal/provider/...`; transport stays in `internal/transport/...`; runtime orchestration stays in `internal/session`.
- Active behavior lives in `openspec/specs/*/spec.md` plus any approved active change under `openspec/changes/`.

## Primary entrypoints

| Path | Role | Use when |
| --- | --- | --- |
| `cmd/probe` | provider-only resolution and sanitized artifacts | checking provider contours, invite resolution, challenge paths |
| `cmd/clientd` | local HTTP control plane for shells and hosts | verifying profiles, sessions, challenges, diagnostics, event stream |
| `cmd/tunnel-client` | runtime client entrypoint | investigating end-to-end runtime orchestration |
| `cmd/tunnel-server` | relay/server baseline | checking server-side forwarding and transport behavior |
| `cmd/turnlab-shell` + `test/turnlab` | deterministic harness surface | reproducing relay/runtime integration locally |
| `desktop/gui_shell` | desktop Flutter shell over the local control plane | shell workflow, sidecar discovery, diagnostics export |
| `mobile/gui_shell` | mobile Flutter shell over the local control plane | bridge lifecycle, browser handoff, packaged-host UX |

## Fast commands

```bash
go build ./...
go run ./cmd/probe -list-providers
go run ./cmd/clientd -listen 127.0.0.1:7777
dart pub get
```

Use `docs/build-workflows.md` for packaging and mirror builds.
Use `docs/agent/verification.md` to choose the smallest relevant checks before escalating.

## Read next

- `docs/agent/architecture-map.md`: ownership by subsystem
- `docs/agent/verification.md`: change-to-check matrix
- `docs/provider-matrix.md`: provider support and scope
- `docs/runtime-observability.md`: logs, metrics, stage taxonomy
- `docs/runtime-execution-planning.md`: explicit same-device execution matrix, remote endpoint ownership, and follow-on slices
- `docs/windows-desktop-wg-poc.md`: repo-owned Windows `windows_wintun` ready-path runbook and safe VMware execution cell
- `README.md`: full operator quick start, CLI examples, and deeper workflow details
