# Change: [65] Extract shared workflow library and frame primitives into shell core

## Why
After `Home`, `Profiles`, and managed-provider workflow bodies are shared, the
next repeatable duplication is no longer the editor body itself but the
surrounding library and frame primitives:

- saved-profile and managed-provider list surfaces;
- section headers and summary frames;
- empty and hint cards that express the same product concepts with app-local
  copies.

These are still split between desktop-local widgets and mobile-local root
composition. Consolidating them is the next low-risk step before tackling the
more divergent `Support` and `Routing` surfaces.

## Sequence
- Order: `65`
- Depends on:
  - `refactor-63-flow-1-desktop-core-shared-profile-workflow-surface`
  - `refactor-64-flow-1-desktop-core-shared-managed-provider-workflow-surface`
- Unblocks:
  - shared list and frame reuse across desktop and mobile workflow roots
  - thinner app-local dashboard and workspace composition code
  - later extraction of `Support` and `Routing` content with less duplicated
    frame chrome

## What Changes
- Extract shared list and frame primitives for saved profiles and managed
  providers into `packages/flutter_shell_core`.
- Reuse those primitives from desktop `Profiles` and `Providers` canvases.
- Reuse the same primitives from mobile `Profiles` and `Providers` roots while
  keeping mobile destination shells and overflow actions app-local.

## Impact
- Affected specs:
  - `flutter-shell-workspace`
- Affected code:
  - `packages/flutter_shell_core/lib/src/ui/...`
  - `desktop/gui_shell/lib/src/ui/profile_library_panel.dart`
  - `desktop/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`

