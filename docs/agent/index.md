# Agent Docs Index

Use this directory as the fast entrypoint for Codex and other repository-local agents.
It points to the smallest set of files needed to understand the repo, choose the right owner path, and pick the correct verification commands.

## Start here

- `README.md`: runtime surface, CLI examples, operator-facing quick start
- `docs/agent/architecture-map.md`: subsystem ownership and navigation map
- `docs/agent/verification.md`: change-type to verification matrix
- `docs/provider-matrix.md`: current provider support and scope
- `docs/runtime-observability.md`: log fields, metrics, stage taxonomy
- `docs/adr/0001-go-monorepo.md`: canonical package boundaries

## Task routing

| If the task is about | Read first | Confirm with |
| --- | --- | --- |
| Planning or behavior/architecture changes | `openspec/AGENTS.md`, `openspec/project.md`, relevant `openspec/specs/*/spec.md` | `openspec list`, `openspec show`, matching code/tests |
| Provider resolution or VK contour behavior | `test/compatibility/AGENTS.md`, `test/compatibility/vk/README.md`, `docs/provider-matrix.md` | `internal/provider/...`, committed fixtures, probe tests |
| Client runtime or supervision | `docs/agent/architecture-map.md`, `openspec/specs/tunnel-client-runtime/spec.md`, `docs/runtime-observability.md` | `internal/session`, `test/turnlab`, runtime compatibility tests |
| Local client control plane or GUI host wiring | `pkg/clientcontrol`, `cmd/clientd`, `openspec/changes/add-01-client-control-plane/*` | `go test ./pkg/clientcontrol ./cmd/clientd` |
| TURN/DTLS transport or server behavior | `docs/agent/architecture-map.md`, `docs/adr/0001-go-monorepo.md` | `internal/transport`, `internal/tunnelserver`, harness tests |
| Observability | `docs/runtime-observability.md`, `openspec/specs/runtime-observability/spec.md` | `internal/observe`, runtime entrypoint tests |
| Code review | `code_review.md` | diff + relevant specs/tests |
| Docs/onboarding changes | `AGENTS.md`, this index | referenced paths and command examples |

## Default workflow

1. Read the smallest matching docs above.
2. Find the owning code and tests from `docs/agent/architecture-map.md`.
3. Pick the minimum verification set from `docs/agent/verification.md`.
4. Only claim behavior that is backed by code, tests, specs, or committed compatibility evidence.
