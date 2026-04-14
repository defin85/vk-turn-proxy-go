# Desktop GUI Shell Instructions

## Read First

- `desktop/gui_shell/README.md`
- `openspec/specs/desktop-gui-client/spec.md`
- `openspec/specs/platform-tunnel-integration/spec.md`
- `.agents/skills/vk-turn-desktop-shell/SKILL.md`

## Guardrails

- Keep host and platform-tunnel state fail-closed and explicit in the UI.
- Keep diagnostics and live-work surfaces secondary to the main profile and resolve/start workflow.
- Do not move provider-specific browser logic into the Flutter layer.
- Prefer workflow-first pane composition over dashboard-style peer-card layouts.

## Verification

- Run `dart pub get` from the repository root before shell-local checks.
- Run `cd desktop/gui_shell && flutter analyze && flutter test`.
- If host negotiation or sidecar behavior changes, also run `go test ./pkg/clientcontrol ./cmd/clientd`.
