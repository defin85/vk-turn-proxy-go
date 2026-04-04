<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Local instructions for Codex

## First pass
- Start with `docs/agent/index.md` for the repo map and task routing.
- Use `README.md` for the runtime/operator surface.
- Use `openspec/project.md` plus `openspec/specs/*/spec.md` as the checked-in behavior contract.
- For compatibility or wire-behavior work, also open `test/compatibility/AGENTS.md`.

## Escalation triggers
- Open `openspec/AGENTS.md` before planning or proposing behavior/architecture changes.
- Open `code_review.md` for review requests or when you need the repo review rubric.

## Repo map
- `cmd/`: operator entrypoints (`probe`, `tunnel-client`, `tunnel-server`)
- `internal/provider/`: provider-specific signaling and credential resolution
- `internal/transport/`: provider-agnostic TURN/DTLS/UDP primitives
- `internal/session/`: client runtime orchestration and supervision
- `internal/observe/`: structured logs and metrics
- `test/compatibility/`: replayable compatibility contracts and fixtures
- `test/turnlab/`: deterministic integration harness
- `openspec/`: behavior and architecture source of truth

## Search workflow
- Search order: `mcp__claude_context__search_code` -> `rg` -> `rg --files` -> targeted file reads.
- Use the canonical repo root `/home/egor/code/vk-turn-proxy-go/` for semantic indexing tools.
- Start with narrow queries and set `extensionFilter` early.
- Do not treat plans, tasks, or TODO lists as proof that behavior exists.
- For provider and wire-behavior questions, confirm claims in at least two sources: code + tests/spec/docs.

## Guardrails
- This repository is the canonical codebase for the Go rewrite; `/home/egor/code/vk-turn-proxy` is the compatibility oracle, not the place for new product changes.
- Keep provider-specific signaling and credential resolution inside `internal/provider/...`.
- Keep TURN/DTLS/UDP transport logic provider-agnostic.
- Keep runtime/config/logging/metrics out of transport packages.
- Fail closed on provider failures; do not add silent fallbacks.
- Prefer small packages and files with one responsibility.

## Verification and tracking
- Use `docs/agent/verification.md` to choose the smallest relevant verification set.
- For Go changes, escalate to `go test ./...` and `go build ./...` when the smaller relevant checks pass.
- Run `bd prime` for workflow context, track work in Beads, and keep approved OpenSpec tasks aligned with Beads.
