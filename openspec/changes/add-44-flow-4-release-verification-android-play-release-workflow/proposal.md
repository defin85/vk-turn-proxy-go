# Change: [44] Add Android Google Play release workflow

## Why
The repository can currently build and stage a debug Android APK for local
device work, but that path is not a Google Play publication workflow.

Today the repo-owned Android packaging surface still has three publish blockers:
- the documented WSL workflow stages only `app-debug.apk`
- Android `release` still falls back to the debug signing config
- the debug packaging lane can stage repo-local development assets such as the
  seeded `phone1.conf` WireGuard profile

That is enough for local iteration, but it is not a store-ready release lane.
Google Play publication needs an explicit repo-owned Android release workflow
that produces a signed upload artifact, keeps debug-only workstation state out
of the published package, and documents the operator-owned Play Console handoff
instead of leaving it as ad hoc tribal knowledge.

## Sequence
- Order: `44`
- Depends on:
  - `refactor-43-relaydock-package-bundle-id-migration`
  - the existing packaged-host Android mobile slice
- Unblocks:
  - Google Play internal or closed testing from repo-owned release artifacts
  - a later production rollout without reusing debug packaging shortcuts
  - explicit operator runbooks for release signing and Play Console submission

## What Changes
- Add a documented repo-owned Android release entrypoint that stages a signed
  Google Play upload artifact from WSL instead of only producing a debug APK.
- Replace the current debug-signing fallback for Android `release` with an
  explicit upload-key signing contract that fails closed when signing inputs are
  missing or invalid.
- Define the release boundary between store-target packages and debug-only
  mobile workflows so repo-local seeded assets such as the development
  WireGuard profile do not leak into Play-target builds.
- Add release preflight rules for current Play submission prerequisites that
  belong in the repo-owned build lane, such as a repo-managed minimum Android
  target floor and explicit release packaging checks.
- Document the operator-owned handoff from the staged release artifact into
  Google Play Console, including app signing enrollment, test-track upload,
  store listing/contact details, and app-content declarations.
- Keep actual Play Console account setup, legal review, policy text drafting,
  and automated store upload APIs out of scope for this change.

## Impact
- Affected specs:
  - `native-build-workflows`
  - `mobile-gui-client`
- Affected code:
  - `mobile/gui_shell/android/app/build.gradle.kts`
  - `scripts/build-android-gui-linux.sh`
  - Android release-signing and packaging helpers
  - release handoff docs under `docs/`
