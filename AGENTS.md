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
- Read `DEBUG.md` when the task needs a verified UI launch/reload runbook.
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
- Direct Android device testing is available when a phone or tablet is reachable over USB or ADB-over-Wi-Fi with debugging enabled and authorized.
- The primary Flutter UI workflow is Dart MCP-first. Stay inside Dart MCP launch/DTD/hot-reload tooling unless the user explicitly agrees to switch to `adb`-driven install/logcat/forward/input work in the current thread.
- When that explicit agreement exists, prefer the Linux `adb` on `PATH` or under `~/.local/share/android-sdk/platform-tools/adb` for physical-device install/logcat/forward/intent checks so pairing, forwarded ports, local HTTP probes, and APK paths stay inside one environment.
- Use the Windows Android SDK `adb.exe` at `C:\Users\Egor\AppData\Local\Android\Sdk\platform-tools\adb.exe` (WSL path `/mnt/c/Users/Egor/AppData/Local/Android/Sdk/platform-tools/adb.exe`) only when the agreed task specifically depends on Windows-side tooling, the Windows mirror workflow, or a Windows-only pairing state that has not been re-established in WSL yet.
- The Windows Android SDK root is `C:\Users\Egor\AppData\Local\Android\Sdk`, the Windows Flutter SDK used by the repo-owned mirror builds is `C:\flutter`, and the Windows mirror root is `E:\Projects\vk-turn-proxy-go`.
- For the fastest desktop Flutter UI debug loop, prefer WSLg with the Linux target over the Windows mirror workflow.
- The primary Flutter UI workflow is Dart MCP-first. Use `mcp__dart__.launch_app` with a plain filesystem `root` path, not a `file://...` URI.
- The verified desktop MCP launch path is: start `go run ./cmd/clientd -listen 127.0.0.1:7777`, then `mcp__dart__.launch_app(device="linux", root="/home/egor/code/vk-turn-proxy-go/desktop/gui_shell")`.
- In a fresh desktop-dedicated Codex session, connect to the returned DTD URI and use Dart MCP `hot_reload` and inspection tools.
- The verified mobile MCP path is: `mcp__dart__.launch_app(device="<adb-serial>", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell")`, then connect to the returned DTD URI and use Dart MCP `hot_reload` and inspection tools.
- For Android WebView or IME regressions inside the mobile shell, a repo-owned MCP harness exists at `mobile/gui_shell/test_driver/owned_browser_harness_main.dart`.
- That harness is an explicit debug mode, not the default app entrypoint. Keep its live diagnostics disabled by default and only flip the local toggle on when the current task needs native/DOM visibility for owned-browser investigation.
- Dart MCP currently keeps one active DTD connection per Codex session. Work on one UI target per session; start a fresh Codex session before switching between desktop and mobile.
- For screenshot or Flutter Driver automation on Linux desktop, launch `desktop/gui_shell` with `flutter run --machine -d linux -t test_driver/driver_main.dart`, but keep `enableTextEntryEmulation` disabled in that entrypoint so real keyboard input on the live WSLg window keeps working.
- If an automation step truly needs `FlutterDriver.enterText`, enable text-entry emulation only for that session and turn it back off afterwards; do not bake emulated text entry into the app entrypoint.
- Use the Windows mirror and `flutter run -d windows` only when the task specifically needs Windows-native behavior, packaging, or sidecar-placement validation.
