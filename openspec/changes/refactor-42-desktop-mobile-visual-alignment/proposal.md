# Change: [42] Align desktop visual language with the mobile shell

## Why
The mobile shell now has the clearest product feel in the repository. Its
surface hierarchy, status language, form treatments, and overall polish read
as one coherent application.

The desktop shell has stronger information architecture than before, but it
still looks like a related tool rather than the same product family. The gap is
not only layout; it is also the color system, surface treatment, status tone,
and component styling.

Desktop now needs a dedicated visual-alignment change that uses the mobile app
as the reference while preserving desktop-first workflows and workbench
behavior.

## Sequence
- Order: `42`
- Depends on:
  - `add-30-desktop-vpn-workbench-shell`
  - `refactor-12-flutter-workspace-shell-core`
- Unblocks:
  - one recognizable cross-shell product identity
  - shared visual primitives instead of desktop/mobile style drift
  - later desktop polish that can build on a settled product language

## What Changes
- Define the current mobile shell as the visual reference for the desktop shell.
- Align desktop color semantics, surface hierarchy, status treatments, action
  emphasis, and core component styling with the mobile product language.
- Move reusable cross-shell visual primitives into `packages/flutter_shell_core`
  when they are platform-neutral.
- Preserve desktop-first layout, density, keyboard flow, and resize behavior
  instead of turning desktop into a stretched phone UI.

## Impact
- Affected specs:
  - `desktop-gui-client`
  - `flutter-shell-workspace`
- Affected code:
  - `desktop/gui_shell/lib/src/ui/...`
  - `packages/flutter_shell_core/lib/...`
  - desktop widget coverage, screenshots, and design reference assets
