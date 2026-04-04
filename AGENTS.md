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

## Scope
- This repository is the canonical codebase for the Go rewrite.
- The legacy repository `/home/egor/code/vk-turn-proxy` is a reference implementation and compatibility oracle, not a place for new product changes.

## Project Docs
- Start with `README.md` for the current runtime/operator surface.
- Use `openspec/project.md` plus `openspec/specs/*/spec.md` as the checked-in behavior contract.
- For provider compatibility and wire-behavior work, start with `test/compatibility/README.md`, `test/compatibility/vk/README.md`, and the relevant fixtures before changing code.
- Use `docs/provider-matrix.md`, `docs/runtime-observability.md`, and `docs/adr/0001-go-monorepo.md` as the repo-owned architecture and runtime references.

## Search Playbook
- Search order: `mcp__claude_context__search_code` -> `rg` -> `rg --files` -> targeted file reads.
- Use the canonical repo root `/home/egor/code/vk-turn-proxy-go/` for semantic indexing tools; use the same absolute path for index, status, clear, and search.
- Form the first semantic query as `component + action + context` and keep the first pass narrow.
- Set `extensionFilter` early when using semantic search:
  - Go implementation: `.go`
  - Specs/docs/instructions: `.md`
  - Compatibility fixtures/evidence: `.json`
  - CI/workflows: `.yml`
- Prioritize `internal/`, `cmd/`, `openspec/`, `test/compatibility/`, `docs/`, `README.md`, and `AGENTS.md` when narrowing search scope.
- For OpenSpec work, use `openspec list`, `openspec list --specs`, and `openspec show` first; treat `rg` as full-text fallback.
- For provider and wire-behavior questions, confirm findings in at least two sources: code + tests/spec/docs.
- Do not treat plans, tasks, TODO lists, or status files as proof that behavior is implemented.

## Architecture rules
- Keep provider-specific signaling and credential resolution inside `internal/provider/...`.
- Keep TURN/DTLS/UDP transport logic provider-agnostic.
- Keep runtime concerns such as flags, config loading, logging, metrics, and service integration out of transport packages.
- New behavior-changing work must preserve explicit traceability: `requirement -> code -> test`.

## Compatibility rules
- Before changing wire behavior, define the compatibility scenario first.
- Prefer adding or updating an integration/compatibility test over arguing from inspection.
- Do not silently add fallback behavior for provider failures; fail closed with explicit errors.

## Complexity rules
- Prefer small packages with one responsibility.
- Avoid files growing beyond 300 lines unless there is a clear reason.
- Avoid mixed provider + transport + orchestration code in one file.

## Verification
- For Go changes, run the smallest relevant test set first, then `go test ./...` and `go build ./...` when feasible.

## Issue Tracking
- This repository uses `bd (beads)` for issue tracking. Run `bd prime` for the current workflow context.
- Prefer `bd ready`, `bd show <id>`, `bd create "Title" --type task --priority 2`, and `bd close <id>`.
- Use `--json` for machine-readable output and do not keep parallel markdown TODO/task lists.
- When work comes from an approved OpenSpec change, keep the related Beads issues aligned with `openspec/changes/<change-id>/tasks.md`.
