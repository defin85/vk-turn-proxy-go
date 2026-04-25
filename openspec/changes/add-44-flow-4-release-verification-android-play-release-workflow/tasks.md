## Current progress
- [x] 2026-04-25: Submitted Google Play Console Android developer
      verification ownership proof for package name `com.defin85.relaydock`.
      The proof used the Play-selected existing debug signing certificate
      fingerprint `0C:75:...:13:E8` and a one-off APK containing the
      Play-provided `assets/adi-registration.properties` challenge. Play Console
      review is pending and expected to take up to 48 hours.
- [ ] After Play Console marks the package name registered, add a normal
      release/upload key as an additional key and continue the signed Play
      release lane. Do not treat the debug-key proof APK as a publishable
      release artifact.

## 1. Release contract
- [ ] 1.1 Define the Google Play-target Android release artifact contract,
      including the staged artifact type, signing prerequisites, SHA-256
      checksum/metadata, and explicit non-goals for operator-owned Play Console
      work.
- [ ] 1.2 Define the boundary between store-target Android packages and the
      existing debug-only mobile workflow so local workstation assets do not
      silently cross into the release lane.

## 2. Build workflow and packaging
- [ ] 2.1 Add a repo-owned Android release build entrypoint from WSL that
      stages a Play-upload artifact from the canonical version and publish
      identity sources instead of only building a debug APK.
- [ ] 2.2 Replace the current debug-signing fallback with explicit upload-key
      signing configuration that fails closed when the keystore path, alias, or
      passwords are missing or invalid.
- [ ] 2.3 Add release preflight checks for Play-target packaging, including the
      effective `targetSdkVersion` against an explicit repo-managed Android
      target floor and checks that reject development-only assets by release
      package content inspection.

## 3. Docs and operator handoff
- [ ] 3.1 Document the release signing inputs, repo-owned Android release
      entrypoint, staged artifacts, and local verification path.
- [ ] 3.2 Document the operator-owned Google Play handoff, including Play App
      Signing enrollment, release-track upload, store listing/contact details,
      app-content declarations, and manifest-derived policy surfaces such as
      Data safety, privacy/support contact, content rating, target audience, VPN
      service, `QUERY_ALL_PACKAGES`, camera, and foreground service use when
      present, without claiming that the repo-owned scripts publish directly to
      the store.

## 4. Verification
- [ ] 4.1 Add or update targeted checks that prove the Android release
      packaging lane fails closed on missing/invalid signing, produces the
      intended signed upload artifact with checksum metadata, enforces the
      documented target SDK floor, and excludes repo-local debug assets from the
      AAB by content inspection.
- [ ] 4.2 Run `openspec validate add-44-flow-4-release-verification-android-play-release-workflow --strict --no-interactive`.
