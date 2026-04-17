# Change: Add Flutter shell internationalization architecture

## Why

The Flutter shells are still hardcoded to English even though the repository
now has a shared Flutter workspace and a shared shell core package. A
shell-local translation pass would only localize top-level buttons while
leaving shared widgets, model-backed display labels, and provider descriptor
metadata partially untranslated.

The repository needs one explicit internationalization architecture before
further shell growth makes copy ownership and fallback behavior harder to
untangle.

## What Changes

- Add a repo-owned shared shell localization package for desktop, mobile, and
  `flutter_shell_core`.
- Define shell locale ownership, defaulting, persistence, and explicit
  operator override behavior.
- Extend the local client control-plane display metadata so provider names,
  descriptions, setting labels, and availability or validation messages can be
  localized without changing machine-readable ids.
- Require clean fallback behavior when a locale is unsupported or a host still
  returns only base strings.

## Impact

- Affected specs: `flutter-shell-workspace`, `mobile-gui-client`,
  `desktop-gui-client`, `client-control-plane`
- Affected code: `desktop/gui_shell`, `mobile/gui_shell`,
  `packages/flutter_shell_core`, new shared Flutter i18n package under
  `packages/`, local control-plane request and response models, shell test
  helpers, and shell docs
