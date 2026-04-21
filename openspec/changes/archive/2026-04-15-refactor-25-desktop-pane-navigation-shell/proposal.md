# Change: [25] Refactor desktop GUI into a pane-based shell

## Why
The desktop shell is no longer a monolithic dashboard, but it still behaves
like one visually.

The current screen gives near-equal weight to the top status band, the library
stack, the active workspace, and the diagnostics column. That keeps every
surface technically visible, yet it still makes the operator parse competing
panels before the main task becomes obvious.

The shell should now move from "workflow-first cards" to an explicit
desktop-oriented pane model: leading navigation, primary body panes, and
secondary inspectors with progressive disclosure.

## Sequence
- Order: `25`
- Depends on: `refactor-23-desktop-gui-workflow-first-layout`,
  `update-23-app-owned-provider-catalog`
- Unblocks: later desktop support and tunnel-surface polish, including
  follow-up work under `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`

## What Changes
- Refactor the desktop shell from a competing multi-card dashboard into a
  pane-based shell with distinct ownership for navigation, task editing, and
  support inspection.
- Replace the current stacked library card with explicit desktop navigation for
  primary shell sections, while keeping presets subordinate to the managed
  provider workflow instead of promoting them back into a peer taxonomy.
- Start the pane model with a small set of primary desktop sections centered on
  the profile workflow and the managed-provider workflow instead of promoting
  diagnostics or live activity into peer top-level navigation immediately.
- Move diagnostics, tunnel detail, events, and live activity into contextual
  secondary inspector surfaces instead of a permanently dominant peer column.
- Reduce the current hero-like operational band into a compact shell bar that
  keeps blocked/error state explicit without front-loading routine status above
  the main task canvas.
- Define adaptive pane transitions for resizable desktop windows so navigation
  and inspectors can collapse or expand without discarding operator context.
- Keep provider, profile, resolution, and session semantics unchanged; this is
  a shell-structure change, not a control-plane or runtime-behavior change.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: `desktop/gui_shell/lib/src/ui/...`,
  `desktop/gui_shell/test/...`, desktop shell docs/screenshots
