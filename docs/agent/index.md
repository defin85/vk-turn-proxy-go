# Agent Docs Index

Use this directory as the fast entrypoint for Codex and other repository-local agents.
It points to the smallest set of files needed to understand the repo, choose the right owner path, and pick the correct verification commands.

## Always read

- `make codex-onboard`: fast repo-owned context refresh across agent docs and OpenSpec
- `make codex-onboard-workflow`: same plus current git/Beads workflow state when the task needs mutable execution context
- `docs/agent/runtime-surface.md`: concise runtime/operator surface and primary entrypoints
- `docs/agent/architecture-map.md`: subsystem ownership and navigation map
- `docs/agent/verification.md`: change-type to verification matrix

## Task-scoped references

- `docs/build-workflows.md`: local and CI build entrypoints for Go plus current Flutter shell workflows
- `docs/provider-matrix.md`: current provider support and scope
- `docs/runtime-observability.md`: log fields, metrics, stage taxonomy
- `docs/adr/0001-go-monorepo.md`: canonical package boundaries

## Scenario runbooks

- `docs/windows-desktop-wg-poc.md`: validated Windows desktop `WireGuard` over transport operator flow
- `docs/windows-desktop-live-vk-workflow.md`: real VK invite preflight into the packaged Windows desktop flow
- `docs/android-wg-phone-poc.md`: validated Android physical-device workflow with the packaged mobile shell

## Repo-local skills

- `.agents/skills/vk-turn-desktop-shell/SKILL.md`: product-specific desktop-shell rules for hierarchy, fail-closed host state, diagnostics placement, and provider workflow UI

## Task routing

| If the task is about | Read first | Confirm with |
| --- | --- | --- |
| Planning or behavior/architecture changes | `openspec/AGENTS.md`, `openspec/project.md`, relevant `openspec/specs/*/spec.md` | `openspec list`; `openspec show <change-or-spec>`; matching code/tests |
| Provider resolution or VK contour behavior | `test/compatibility/AGENTS.md`, `test/compatibility/vk/README.md`, `docs/provider-matrix.md` | `go test ./internal/provider/... ./cmd/probe` |
| Client runtime or supervision | `docs/agent/architecture-map.md`, `openspec/specs/tunnel-client-runtime/spec.md`, `docs/runtime-observability.md` | `go test ./internal/session`; `go test ./test/turnlab -run TestHarnessRelayRoundTrip` |
| Local client control plane or GUI host wiring | `pkg/clientcontrol`, `cmd/clientd`, `openspec/specs/client-control-plane/spec.md` | `go test ./pkg/clientcontrol ./cmd/clientd` |
| Desktop Flutter shell | `desktop/gui_shell/README.md`, `.agents/skills/vk-turn-desktop-shell/SKILL.md`, `openspec/specs/desktop-gui-client/spec.md`, `openspec/specs/platform-tunnel-integration/spec.md` | `dart pub get`; `cd desktop/gui_shell && flutter analyze && flutter test` |
| Mobile Flutter shell | `mobile/gui_shell/README.md`, `docs/android-wg-phone-poc.md`, `openspec/specs/mobile-gui-client/spec.md`, `openspec/specs/android-embedded-mobile-host/spec.md` | `dart pub get`; `cd mobile/gui_shell && flutter analyze && flutter test` |
| Android embedded host or mobile bridge wiring | `mobile/gui_shell/README.md`, `openspec/specs/android-embedded-mobile-host/spec.md`, `cmd/android-mobile-host`, `internal/androidembeddedhost` | `go test ./internal/androidembeddedhost ./pkg/clientcontrol` |
| Build scripts, packaging, or CI workflows | `docs/build-workflows.md`, `Makefile`, `openspec/specs/native-build-workflows/spec.md` | `./scripts/build-go-matrix.sh windows/amd64`; `make smoke-android-embedded-host`; `make ci` |
| TURN lab harness or manual harness shell | `README.md` harness section, `openspec/specs/turn-lab-harness/spec.md`, `test/turnlab`, `cmd/turnlab-shell` | `go test ./test/turnlab -run TestHarnessRelayRoundTrip` |
| TURN/DTLS transport or server behavior | `docs/agent/architecture-map.md`, `docs/adr/0001-go-monorepo.md` | `go test ./internal/transport ./internal/tunnelserver` |
| Observability | `docs/runtime-observability.md`, `openspec/specs/runtime-observability/spec.md` | `go test ./internal/observe ./cmd/tunnel-client ./cmd/tunnel-server` |
| Code review | `code_review.md` | diff + relevant specs/tests |
| Docs/onboarding changes | `AGENTS.md`, this index, `Makefile`, `scripts/verify-agent-docs.py` | `make verify-docs`; `git diff --check` |

## Default workflow

1. Run `make codex-onboard` for the stable repo refresh, or `make codex-onboard-workflow` when the task depends on current git/Beads state.
2. Read the smallest matching docs above.
3. Find the owning code and tests from `docs/agent/architecture-map.md`.
4. Pick the minimum verification set from `docs/agent/verification.md`.
5. Only claim behavior that is backed by code, tests, specs, or committed compatibility evidence.
