## Context

The add-44 Play release workflow completed the repository-owned artifact lane:
the signed AAB was produced, fingerprinted, validated, and handed to Play
Console. That does not prove the Play-delivered app launches on the operator's
smartphone.

The reported failure is specifically about the app published on 2026-04-26 not
launching on the operator's smartphone. The investigation must not collapse
that into a local `flutter run` or debug APK result.

## Goals

- Identify the real startup failure source using evidence from the affected
  smartphone.
- Preserve the distinction between local build verification, sideloaded
  artifacts, and Play-installed artifacts.
- Produce a fix or operator action that can be verified on the same smartphone.
- Leave a reusable runbook update if the investigation reveals a repeated
  release-validation gap.

## Non-Goals

- Redesign the release lane before the crash/failure evidence is captured.
- Treat a local debug launch as proof that the Play-installed app works.
- Automate Play Console release management.
- Broaden the scope to unrelated Android VPN, provider, or desktop issues unless
  the startup evidence points there.

## Investigation Sequence

1. Record the exact device, Android version, install source, package version,
   versionCode, signing certificate, and whether the install came from Play or a
   sideloaded artifact.
2. Capture the failing launch with timestamps and logcat scoped to
   `com.defin85.relaydock`, including Java exceptions, native tombstones,
   linker errors, Flutter engine failures, and Android package-manager events.
3. Compare the Play-installed package against the staged release metadata:
   package id, version, signer, ABI/native libraries, manifest permissions, and
   build identity.
4. Reproduce with the nearest local artifact only after the Play-installed
   behavior is documented, so local reproduction can narrow the difference
   instead of replacing the original failure.
5. Apply the smallest root-cause fix and verify on the same smartphone through
   the distribution path that failed.

## Evidence Bar

The change can only close when there is a trace:

```text
observed smartphone failure -> root cause -> fix/operator action -> same-device
published-install launch evidence
```

Accepted launch evidence is either:

- a successful first frame or driver/screenshot evidence from the published
  install, or
- a resolved Play/store delivery blocker with explicit proof that the corrected
  artifact is available for install and no longer hits the original failure.

## Risks

- Wireless ADB may disconnect around VPN startup, so startup investigation
  should prefer USB ADB when available.
- Play delivery may lag behind a newly uploaded artifact; the investigation must
  record the installed versionCode and signer instead of assuming the latest
  upload is on the device.
- A local release build can mask Play-only issues such as split delivery,
  signing lineage, or stale tester install state.
