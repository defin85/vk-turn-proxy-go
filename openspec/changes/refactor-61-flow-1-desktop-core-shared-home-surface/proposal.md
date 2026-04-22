# Change: [61] Extract the shared Home workflow surface from mobile into shell core

## Why
The current mobile shell has the clearest product-first `Home` surface in the
repository: it focuses on the selected profile or empty state, the current
mode, one primary connect or disconnect action, and explicit support drill-down.

The desktop shell already has a stronger shell contract, but its `Home`
workbench still spends too much space on route-restating quick actions and
parallel overview cards that do not add proportionally more workflow depth.
That makes desktop noisier than mobile while providing similar functional
coverage.

The next step should be a narrow refactor that keeps desktop-specific shell
ownership intact while moving the product-facing `Home` body into shared shell
code and reusing it from both apps.

## Sequence
- Order: `61`
- Depends on:
  - `add-30-flow-1-desktop-core-vpn-workbench-shell`
  - `refactor-42-flow-1-desktop-core-desktop-mobile-visual-alignment`
- Unblocks:
  - shared workflow-body reuse instead of desktop/mobile `Home` drift
  - a quieter desktop first read without weakening desktop navigation or
    inspectors
  - later extraction of shared `Profiles`, `Providers`, `Routing`, and
    `Support` bodies if the `Home` migration succeeds

## What Changes
- Extract the current mobile `Home` workflow body into
  `packages/flutter_shell_core` as a platform-neutral shared surface.
- Keep mobile shell navigation, browser/share adapters, and lifecycle behavior
  app-local while reusing the shared `Home` body.
- Replace the desktop `Home` workbench body with that shared `Home` surface
  inside the existing desktop shell canvas.
- Reduce desktop-local duplicated `Home` chrome that only restates navigation
  or support entry points already available through the left pad or inspector
  model.

## Impact
- Affected specs:
  - `desktop-gui-client`
  - `flutter-shell-workspace`
- Affected code:
  - `packages/flutter_shell_core/lib/src/ui/...`
  - `desktop/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`
  - desktop/mobile widget coverage for the `Home` route
