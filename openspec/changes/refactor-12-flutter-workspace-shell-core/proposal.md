# Change: [12] Introduce a repo-owned Flutter workspace with a shared shell core

## Why
`desktop/gui_shell` and `mobile/gui_shell` now share a meaningful amount of
platform-neutral shell code, but they still resolve and evolve as fully
separate Flutter packages.

At the same time, collapsing both products into one Flutter app package would
mix two different runtime ownership models:

- desktop sidecar supervision and file-backed desktop state
- mobile native host bridge, secure storage, lifecycle, and browser handoff

This change takes the narrower path: one repo-owned Flutter workspace and one
shared shell core package, while keeping desktop and mobile as separate app
packages.

## Sequence
- Order: `12`
- Depends on: `add-02-desktop-gui-shell`, `add-03-mobile-gui-shell`,
  `add-11-build-version-surfacing`
- Unblocks: future desktop/mobile shell work that should reuse one shared
  control-plane-facing layer without merging the apps

## What Changes
- Add one repository-root Flutter/Dart workspace for the shell packages using
  an explicit workspace member list.
- Add one shared pure Flutter package for platform-neutral shell code.
- Keep `desktop/gui_shell` and `mobile/gui_shell` as separate app packages
  with separate runtime wiring and packaging flows.
- Update repo-owned shell build, dependency, verification, and documentation
  wiring for the workspace topology, including a public developer workflow that
  starts with repository-root workspace resolution.

## Impact
- Affected specs: `flutter-shell-workspace`, `native-build-workflows`
- Affected code: repository-root shell package wiring, new
  `packages/flutter_shell_core`, `desktop/gui_shell`, `mobile/gui_shell`,
  shell build/test scripts, shell docs, CI shell verification
