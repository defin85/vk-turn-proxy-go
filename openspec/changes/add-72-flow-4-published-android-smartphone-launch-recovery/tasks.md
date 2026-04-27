## Current Progress

- [x] 2026-04-27: Start investigation with the operator smartphone that failed
      to launch the RelayDock build published on 2026-04-26.
- [x] 2026-04-27: Add a pinned `bundletool-all` local-delivery gate that
      reproduces the delivered split set and blocks release artifacts missing
      the Android embedded-host JNI bridge callback names.
- [x] 2026-04-27: Preserve the Android platform tunnel bridge callback surface
      in release AABs and rebuild a signed Play release artifact that passes
      the local-delivery gate.
- [ ] 2026-04-27: Upload the rebuilt AAB to Play and capture same-smartphone
      launch evidence after Play delivery updates.

## 1. Device Evidence

- [x] 1.1 Identify the affected smartphone: Android version, CPU ABI, install
      source, package versionName/versionCode, signer fingerprint, and whether
      the installed package came from Play or a local sideload.
- [x] 1.2 Capture a timestamped failing launch from the installed package with
      `adb`/device evidence rather than relying on Play Console symptoms alone.
- [x] 1.3 Collect scoped logs for `com.defin85.relaydock`, including Java
      exceptions, native crashes/tombstones, linker errors, Flutter engine
      startup failures, and package-manager install or launch errors.

## 2. Artifact Comparison

- [x] 2.1 Compare the installed package identity and signer against
      `dist/mobile/android-play-release/build-metadata.json` and the
      Play-confirmed upload key.
- [x] 2.2 Verify the installed package contains the expected release ABI/native
      libraries and does not depend on debug-only bridge or WireGuard seed
      assets.
- [x] 2.3 If the Play-installed package cannot be inspected directly, document
      the limitation and reproduce with the nearest locally installable artifact
      only as a secondary comparison.
      - The Play-installed package was inspectable directly; local bundletool
        reproduction is kept as secondary release-lane evidence.

## 3. Root Cause and Fix

- [x] 3.1 Classify the root cause as one of: Play delivery/install state,
      signing/package identity, Android compatibility, native library loading,
      Kotlin startup bridge, Flutter first-frame startup, embedded-host
      bootstrap, or other evidence-backed category.
- [x] 3.2 Implement the smallest repo or operator fix needed for the confirmed
      root cause.
- [x] 3.3 Update release docs or checks if the failure exposes a reusable
      validation gap in the Play release lane.

## 4. Verification

- [ ] 4.1 Rebuild, republish, or reinstall through the same distribution path
      that failed, as required by the root cause.
- [ ] 4.2 Prove the app launches on the same smartphone with first-frame,
      screenshot, or equivalent device evidence.
- [x] 4.3 Run the smallest relevant repo checks for the touched layer, plus
      `openspec validate add-72-flow-4-published-android-smartphone-launch-recovery --strict --no-interactive`.
