## 1. Contract and packaging model
- [x] 1.1 Define the Android embedded host ownership, bootstrap, and lifecycle model
- [x] 1.2 Define packaged versioning rules between the Flutter GUI and the embedded host
- [x] 1.3 Define the development-only external bridge override boundary for Android

## 2. Android embedded host delivery
- [x] 2.1 Add a reusable Android host runtime wrapper around the canonical runtime packages
- [x] 2.2 Add Android packaging and startup glue for the embedded host within the app release
- [x] 2.3 Add an Android app-owned bridge that satisfies the mobile host semantics without an external desktop sidecar

## 3. Verification
- [x] 3.1 Add host-backed Android integration coverage and at least one packaged-host smoke path to `ready`
- [x] 3.2 Run `openspec validate add-14-android-embedded-mobile-host --strict --no-interactive`
