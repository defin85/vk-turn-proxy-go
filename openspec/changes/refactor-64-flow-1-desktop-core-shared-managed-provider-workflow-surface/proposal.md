# Change: [64] Extract the shared managed-provider workflow surface into shell core

## Why
The managed-provider editor is now the next large duplicated workflow body after
`Profiles`. Desktop and mobile both render descriptor-driven provider settings,
save and delete actions, and apply-to-profile behavior, but they still keep
separate `ProviderConfigEditorPanel` implementations.

That duplication already diverges in small but meaningful ways around layout,
action ownership, and entry affordances. The next narrow step should share the
reusable managed-provider workflow body without forcing mobile templates or
desktop route wrappers into one merged shell model.

## Sequence
- Order: `64`
- Depends on:
  - `refactor-62-flow-1-desktop-profiles-providers-route-separation`
  - `refactor-63-flow-1-desktop-core-shared-profile-workflow-surface`
- Unblocks:
  - later extraction of shared provider library and frame primitives
  - one shared contract for reusable provider record editing behavior
  - lower drift risk between desktop `Providers` canvas and mobile provider
    detail screens

## What Changes
- Extract the body-level managed-provider workflow surface into
  `packages/flutter_shell_core`.
- Keep mobile list-first `Providers` root, template catalog, and save-as-template
  entry semantics app-local.
- Keep desktop `Providers` route ownership, preset bootstrap entry, and
  provider-family chooser entry surfaces app-local around the shared editor.

## Impact
- Affected specs:
  - `flutter-shell-workspace`
- Affected code:
  - `packages/flutter_shell_core/lib/src/ui/...`
  - `desktop/gui_shell/lib/src/ui/provider_config_editor.dart`
  - `desktop/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/provider_config_editor.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`

