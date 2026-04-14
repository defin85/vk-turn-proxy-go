# Change: [28] Rebuild the desktop shell around a left pad and one main canvas

## Why
`refactor-27-desktop-single-path-shell` removed some first-screen clutter, but
the current desktop shell still reads like a card dashboard that is trying to
explain the active workspace from the side instead of simply letting the
workspace own the screen.

In practice the shell still shows a persistent stack of explanatory cards,
action cards, and context cards beside the editor. That creates a soft
master-detail anti-pattern: the operator sees summary cards for the same task
that is already open in the main workspace.

The next step should be a stronger layout break:

- a persistent left pad for workflow switching and task entry
- one main canvas that owns the active task surface
- no duplicated "current task" card stack beside the same task's editor
- no modal-first library browsing for routine task switching

## Sequence
- Order: `28`
- Depends on: `refactor-27-desktop-single-path-shell`
- Unblocks: later desktop-shell polish and visual refinement on top of a stable
  left-pad shell model instead of continuing to patch card-based layout

## What Changes
- **BREAKING** Replace the current card-heavy desktop shell body with a
  left-pad shell where the left side is a compact navigation and command pad,
  not a summary-content pane.
- Move saved-profile browsing, preset bootstrap, managed-provider browsing, and
  provider-family selection into dedicated main-canvas task routes instead of
  modal overlays or stacked companion cards.
- Remove persistent "Current focus", "Current task", and similar summary-card
  blocks that restate the same entity already open in the main editor.
- Keep the operational header compact and keep diagnostics/live work as
  secondary inspector surfaces, not left-pad content.
- Preserve profile/provider/runtime semantics; this is a shell information
  architecture refactor, not a control-plane contract change.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: `desktop/gui_shell/lib/src/ui/...`,
  `desktop/gui_shell/lib/src/control/...`, desktop widget tests, shell
  screenshots/reference assets
