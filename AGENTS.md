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
- Run `make codex-onboard` when you need a fast repo-context refresh across agent docs and OpenSpec.
- Run `make codex-onboard-workflow` when you specifically need current git/Beads workflow context.
- Use `docs/agent/runtime-surface.md` for the concise runtime/operator surface.
- Use `README.md` when you need the full operator quick start and CLI examples.
- Use `openspec/project.md` plus `openspec/specs/*/spec.md` as the checked-in behavior contract.
- For compatibility or wire-behavior work, also open `test/compatibility/AGENTS.md`.

## Escalation triggers
- Open `openspec/AGENTS.md` before planning or proposing behavior/architecture changes.
- Open `code_review.md` for review requests or when you need the repo review rubric.

## Repo map
- `cmd/`: operator entrypoints (`probe`, `tunnel-client`, `tunnel-server`, `clientd`, `turnlab-shell`, `turn-expiry-check`, `android-mobile-host`)
- `pkg/clientcontrol/`: versioned local control-plane contract for profiles, sessions, challenges, diagnostics, and negotiation
- `desktop/gui_shell/` and `mobile/gui_shell/`: Flutter shells over the local control plane; each subtree can carry tighter local agent guidance
- `packages/flutter_shell_core/`: shared Flutter workspace package for shell code that should not stay app-local
- `internal/provider/`: provider-specific signaling and credential resolution
- `internal/androidembeddedhost/`: packaged Android embedded-host bootstrap and host-policy wiring
- `internal/overlay/`: native ingress/egress overlay adapters and frame protocol
- `internal/runstage/`: shared runtime stage taxonomy and stage-aware errors
- `internal/transport/`: provider-agnostic TURN/DTLS/UDP primitives
- `internal/turnrest/`: TURN REST expiry parsing helpers and related diagnostics
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
- Run `make verify-docs` for agent-doc, onboarding, or workflow-document changes; it validates repo-path references and fast onboarding entrypoints.
- For Go changes, escalate to `go test ./...` and `go build ./...` when the smaller relevant checks pass.
- Run `bd prime` for workflow context, track work in Beads, and keep approved OpenSpec tasks aligned with Beads.

## Local infrastructure
- The operator VPS is reachable as `ssh vk-turn-proxy-go`.
- Connection details: host `176.109.104.105`, user `egor`, port `22`.
- Use that alias for repo-related remote checks when the user asks to inspect or run something on the VPS.
- `egor-vps` remains as a compatibility alias, but `vk-turn-proxy-go` is the canonical name.
- Keep remote actions non-destructive unless the user explicitly requests otherwise.
- Direct Android device testing is available when a phone is connected over USB with debugging enabled and authorized.
- Prefer the Windows Android SDK `adb.exe` at `C:\Users\Egor\AppData\Local\Android\Sdk\platform-tools\adb.exe` (WSL path `/mnt/c/Users/Egor/AppData/Local/Android/Sdk/platform-tools/adb.exe`) for physical-device install/logcat/intent checks.
- The Windows Android SDK root is `C:\Users\Egor\AppData\Local\Android\Sdk`, the Windows Flutter SDK used by the repo-owned mirror builds is `C:\flutter`, and the Windows mirror root is `E:\Projects\vk-turn-proxy-go`.
