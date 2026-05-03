# Runtime Surface

Use this document when you need the operator/runtime picture without reading the full `README.md`.
It is the concise first-pass view for Codex and other repository-local agents.

## Product slice today

- `vk-turn-proxy-go` is the canonical Go rewrite for the TURN/DTLS tunnel product.
- The legacy repository `/home/egor/code/vk-turn-proxy` remains the compatibility oracle until equivalent coverage exists here.
- Current shipped slices cover provider resolution for `vk` and `generic-turn`, the local client control plane, runtime observability, the turnlab harness, and desktop/mobile Flutter shells.
- The first packaged Windows system-tunnel ready path is now repo-owned through `windows_wintun`; use `docs/windows-desktop-wg-poc.md` for the verified packaged-host and VMware execution-cell runbook.
- The local control plane now exposes typed runtime execution planning so current overlay startup, future packaged `wireguard_native` plans, and later experimental carriers stay explicitly separated.
- VPS-side provider catalogs now live behind `cmd/vps-provider-catalog`, while local `clientd` syncs, validates, and maps remote artifacts into typed provider resolutions.
- Provider logic stays in `internal/provider/...`; transport stays in `internal/transport/...`; runtime orchestration stays in `internal/session`.
- Active behavior lives in `openspec/specs/*/spec.md` plus any approved active change under `openspec/changes/`.

## Primary entrypoints

| Path | Role | Use when |
| --- | --- | --- |
| `cmd/probe` | provider-only resolution and sanitized artifacts | checking provider contours, invite resolution, challenge paths |
| `cmd/clientd` | local HTTP control plane for shells and hosts | verifying profiles, sessions, challenges, diagnostics, event stream |
| `cmd/vps-provider-catalog` | VPS-side provider catalog and remote artifact issue service | testing add-79 catalog sync, artifact issue, audit, and metrics |
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
go run ./cmd/vps-provider-catalog -listen 127.0.0.1:7788 -read-token "$VKTP_CATALOG_READ_TOKEN" -issue-token "$VKTP_CATALOG_ISSUE_TOKEN" -admin-token "$VKTP_CATALOG_ADMIN_TOKEN"
dart pub get
```

Use `docs/build-workflows.md` for packaging and mirror builds.
Use `docs/agent/verification.md` to choose the smallest relevant checks before escalating.

## Read next

- `docs/agent/architecture-map.md`: ownership by subsystem
- `docs/agent/verification.md`: change-to-check matrix
- `docs/provider-matrix.md`: provider support and scope
- `docs/vps-provider-catalog-service.md`: VPS catalog service, sync endpoints, fail-closed rules, and smoke commands
- `docs/runtime-observability.md`: logs, metrics, stage taxonomy
- `docs/runtime-execution-planning.md`: explicit same-device execution matrix, remote endpoint ownership, and follow-on slices
- `docs/windows-desktop-wg-poc.md`: repo-owned Windows `windows_wintun` ready-path runbook and safe VMware execution cell
- `README.md`: full operator quick start, CLI examples, and deeper workflow details
