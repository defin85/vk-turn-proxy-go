# Change: [30] Add desktop VPN workbench shell

## Why
The current desktop shell already moved away from a single monolithic
dashboard, but it still carries too much hybrid profile-workflow and
diagnostics-era structure for a product-grade desktop VPN application.

Comparable desktop clients typically use a clearer workbench shape:

- stable left navigation
- one dominant task canvas
- dedicated routes for profiles, routing, activity, logs, and settings
- compact but persistent live status
- logs and live connections in a bottom ribbon or support-oriented pane rather
  than mixed into the main workflow by default

There is also a simpler desktop-client pattern, represented by `OpenVPN
Connect`, where the app is mostly profile import plus connect or disconnect.
That reference is useful as a contrast, but it is too narrow for this
repository's desktop shell, which already owns richer profile, routing,
activity, and diagnostics workflows.

Desktop now needs an explicit redesign change so the shell becomes a proper VPN
workbench instead of a transitional operator dashboard.

## Sequence
- Order: `30`
- Depends on: `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`, `add-28-flow-1-desktop-core-platform-tunnel-host-boundary`
- Unblocks: a product-grade desktop shell for the future Windows/Linux/macOS
  VPN paths and a cleaner desktop information architecture for later runtime
  work

## What Changes
- Refine `desktop-gui-client` so the desktop shell becomes an explicit VPN
  workbench rather than a profile-editor-centric dashboard with support
  overlays.
- Require a stable destination model such as `Home`, `Profiles`, `Routing`,
  `Activity`, `Diagnostics`, and `Settings`, with one dominant task canvas at a
  time.
- Require desktop home to behave as a concise overview and command surface
  rather than as the place where all editing and support content compete.
- Require logs, connections, and similar live runtime detail to live in a
  bottom ribbon or explicit support surface instead of reclaiming the main
  canvas.
- Require dense desktop workflows for profiles and routing, including dedicated
  list/detail or workbench-style pages rather than stretched mobile layouts.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: `desktop/gui_shell/lib/src/ui/dashboard_page.dart`,
  `desktop/gui_shell/lib/src/ui/profile_library_panel.dart`,
  `desktop/gui_shell/lib/src/ui/profile_editor.dart`, desktop navigation and
  inspector surfaces, and the desktop shell layout/workbench structure
