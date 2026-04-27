# Change: Investigate published Android smartphone launch failure

## Why

The Android Play release lane produced and uploaded a signed RelayDock artifact
on 2026-04-26, but the app reportedly does not launch on the operator's
smartphone after publication. A published-device failure is a different
acceptance surface from local build success: it can come from Play delivery,
signing/package identity, install state, Android compatibility, startup
permissions, packaged native libraries, or first-frame runtime wiring.

The next work slice should capture the real device evidence first, identify the
root cause, and only then change code, packaging, or Play handoff docs.

## What Changes

- Add an evidence-first recovery plan for the Play-distributed RelayDock build
  on the operator smartphone, planned for 2026-04-27.
- Require the investigation to distinguish Play-installed artifact behavior from
  local debug, local release, and sideloaded AAB/APK behavior.
- Require startup evidence from the physical smartphone: install source/version,
  package state, launch result, logcat crash or native abort evidence, and first
  frame or explicit failure.
- Define the closure bar for any fix: rebuild or republish if needed, reinstall
  from the same distribution path, and prove the published app launches on the
  same smartphone.
- Keep Play Console actions operator-owned unless the repo adds a documented
  automation surface in a separate change.

## Impact

- Affected specs: `native-build-workflows`, `mobile-gui-client`
- Affected code: unknown until device evidence is captured; likely candidates
  include Android packaging/signing, embedded-host native library staging,
  Kotlin startup bridge, Flutter entrypoint initialization, or release
  documentation
- Operational impact: requires the operator smartphone to be available through
  USB ADB or another agreed debug path, and may require a Play internal/closed
  test update if the root cause lives in the published artifact
