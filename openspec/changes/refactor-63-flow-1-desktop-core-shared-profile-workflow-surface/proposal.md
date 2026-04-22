# Change: [63] Extract the shared Profile workflow surface from mobile into shell core

## Why
The next large duplication after `Home` is the profile workflow body itself.
Desktop and mobile now agree more closely on shell hierarchy, but both still
carry separate `ProfileEditorPanel` implementations with overlapping field
sync, provider-mode switching, portable-transfer state, and action hierarchy.

That duplication is now the main source of drift in profile behavior and visual
structure. A narrow shared extraction should reuse the clearer mobile
product-facing body while keeping desktop and mobile shell ownership intact.

## Sequence
- Order: `63`
- Depends on:
  - `refactor-61-flow-1-desktop-core-shared-home-surface`
  - `refactor-62-flow-1-desktop-profiles-providers-route-separation`
- Unblocks:
  - later extraction of shared profile/provider library primitives
  - one shared contract for managed-vs-custom profile editing behavior
  - lower drift risk between desktop profile canvas and mobile profile
    workspace

## What Changes
- Extract the body-level profile workflow surface from the current app-local
  implementations into `packages/flutter_shell_core`.
- Keep mobile page navigation, current-profile targeting, and platform-native
  QR/share/file/browser transfer wrappers app-local.
- Keep desktop left-pad routing, canvas-owned chooser flows, and desktop shell
  task ownership app-local while rendering the shared profile body in the
  `Profiles` workspace.

## Impact
- Affected specs:
  - `flutter-shell-workspace`
- Affected code:
  - `packages/flutter_shell_core/lib/src/ui/...`
  - `desktop/gui_shell/lib/src/ui/profile_editor.dart`
  - `desktop/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/profile_editor.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`

