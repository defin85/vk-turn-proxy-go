## 1. Shell contract
- [ ] 1.1 Update the `desktop-gui-client` contract so the active desktop
      workflow owns one dominant editor while adjacent workflows remain
      secondary context.
- [ ] 1.2 Define how routine ready-state, blocked/incompatible state, and live
      runtime state change support-surface prominence in the focused workflow
      shell.
- [ ] 1.3 Keep the existing control-plane, provider, and session semantics
      unchanged while the desktop hierarchy changes.

## 2. Desktop UI implementation
- [ ] 2.1 Refactor the desktop shell body so `profileWorkflow` and
      `providerWorkflow` both render through the same focused-workflow
      composition rules instead of appearing as equal-weight peer regions.
- [ ] 2.2 Replace the current louder workflow/navigation area with a quieter
      context lane for workflow switching, recent records, and seed actions.
- [ ] 2.3 Add a dominant editor header/action hierarchy that makes the next
      meaningful operator step explicit and keeps advanced/support-only detail
      behind progressive disclosure.
- [ ] 2.4 Reduce routine ready-state chrome to a compact assurance block and
      keep diagnostics/activity/tunnel detail on-demand by default.
- [ ] 2.5 Define deterministic escalation rules so blocked/incompatible or
      active runtime states surface the right support context without hiding the
      primary workflow.
- [ ] 2.6 Preserve drafts, selections, and inspector context across workflow
      switches and resize transitions.
- [ ] 2.7 Define explicit focus traversal, shortcut ownership, and primary
      scroll ownership for the context lane, dominant editor, and support
      inspector so desktop input remains deterministic in multi-pane layouts.

## 3. Verification
- [ ] 3.1 Add or update desktop widget coverage for focused workflow landing,
      workflow switching, ready-vs-blocked support visibility,
      resize-preserved state, and on-demand inspector behavior.
- [ ] 3.2 Run `cd desktop/gui_shell && flutter analyze && flutter test`.
- [ ] 3.3 Run `openspec validate refactor-26-desktop-focused-workflow-shell
      --strict --no-interactive`.
