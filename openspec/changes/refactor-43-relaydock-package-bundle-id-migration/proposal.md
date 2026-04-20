# Change: [43] Migrate RelayDock publish identifiers and desktop native output names

## Why
The publication-facing product name is now `RelayDock`, but the native project
identifiers still leak placeholder or legacy shell names such as
`mobile_gui_shell`, `gui_shell`, `com.defin85.mobile_gui_shell`, and
`com.example.guiShell`.

That mismatch is no longer a cosmetic issue. Package and bundle identifiers
flow into Android VPN exclusions, package-oriented automation, Apple signing,
Linux desktop integration, and publication readiness. Changing them later in an
ad hoc way would risk broken debug automation, stale docs, and mixed old/new
platform identity surfaces.

This needs to be treated as an explicit migration change, separate from the
already accepted display-name and icon work.

## Sequence
- Order: `43`
- Depends on:
  - the accepted `RelayDock` publication naming decision
- Unblocks:
  - store-ready mobile and desktop package identities
  - one canonical repo-owned package/bundle ID contract instead of scattered
    placeholder values
  - later follow-up work such as Dart package/import cleanup or artifact-role
    cleanup without mixing internal identity concerns into one oversized
    migration

## What Changes
- Define the canonical RelayDock package/bundle/application identifiers for
  Android, iOS, macOS, and Linux.
- Introduce one dedicated repo-managed publish-identity manifest for those
  identifiers so repo-owned build workflows and validation stop relying on
  scattered hard-coded defaults or on overloaded version metadata.
- Migrate native project metadata, Android package paths, packaging scripts,
  smoke automation, and docs away from `mobile_gui_shell` / `gui_shell`
  identifier surfaces where this change applies.
- Align publication-facing desktop native output names and repo-owned desktop
  launch or staging helpers with the RelayDock shell identity where packaged
  desktop builds still expose legacy shell output stems.
- Add fail-closed verification so packaging does not silently ship mixed legacy
  and canonical identifiers.
- Keep Dart package names, artifact-role strings, and shell state directory
  roots out of scope for this change.

## Impact
- Affected specs:
  - `native-build-workflows`
  - `mobile-gui-client`
  - `desktop-gui-client`
- Affected code:
  - `mobile/gui_shell/android/...`
  - `mobile/gui_shell/ios/...`
  - `desktop/gui_shell/linux/...`
  - `desktop/gui_shell/macos/...`
  - `desktop/gui_shell/windows/...`
  - repo-owned packaging scripts, smoke scripts, launch helpers, and
    publication runbooks
