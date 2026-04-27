## Current progress
- [x] 2026-04-25: Submitted Google Play Console Android developer
      verification ownership proof for package name `com.defin85.relaydock`.
      The proof used the Play-selected existing debug signing certificate
      fingerprint `0C:75:...:13:E8` and a one-off APK containing the
      Play-provided `assets/adi-registration.properties` challenge.
- [x] 2026-04-25: Google confirmed the package ownership proof for the existing
      debug signing certificate. This only confirms the debug-key ownership
      proof and does not make the proof APK a publishable release artifact.
- [x] 2026-04-26: Generated an operator-owned `relaydock-upload` upload key
      outside the repository and exported public certificate
      `relaydock-upload-20260426.pem` for Play Console registration. Upload
      certificate SHA-256 fingerprint:
      `74:30:5F:4E:67:81:FE:7A:81:93:7B:8C:EA:89:D5:A8:04:AC:7C:7C:7F:21:6B:27:18:A1:8E:EE:F0:D2:08:14`.
- [x] 2026-04-26: Play Console confirmed the exported `relaydock-upload`
      certificate as the normal release/upload key. Do not treat the debug-key
      proof APK as a publishable release artifact.
- [x] Continue the signed Play release lane from the confirmed
      `relaydock-upload` key and produce the repo-owned signed Play upload
      artifact.
- [x] 2026-04-26: Produced the signed Play upload AAB at
      `dist/mobile/android-play-release/app-release.aab`; SHA-256
      `0bf6af62cb97984ec266fd65f2bc9da70f60e68a1d989eda54b5854e738dd9d9`.

## 1. Release contract
- [x] 1.1 Define the Google Play-target Android release artifact contract,
      including the staged artifact type, signing prerequisites, SHA-256
      checksum/metadata, and explicit non-goals for operator-owned Play Console
      work.
- [x] 1.2 Define the boundary between store-target Android packages and the
      existing debug-only mobile workflow so local workstation assets do not
      silently cross into the release lane.

## 2. Build workflow and packaging
- [x] 2.1 Add a repo-owned Android release build entrypoint from WSL that
      stages a Play-upload artifact from the canonical version and publish
      identity sources instead of only building a debug APK.
- [x] 2.2 Replace the current debug-signing fallback with explicit upload-key
      signing configuration that fails closed when the keystore path, alias, or
      passwords are missing or invalid.
- [x] 2.3 Add release preflight checks for Play-target packaging, including the
      effective `targetSdkVersion` against an explicit repo-managed Android
      target floor and checks that reject development-only assets by release
      package content inspection.

## 3. Docs and operator handoff
- [x] 3.1 Document the release signing inputs, repo-owned Android release
      entrypoint, staged artifacts, and local verification path.
- [x] 3.2 Document the operator-owned Google Play handoff, including Play App
      Signing enrollment, release-track upload, store listing/contact details,
      app-content declarations, and manifest-derived policy surfaces such as
      Data safety, privacy/support contact, content rating, target audience, VPN
      service, `QUERY_ALL_PACKAGES`, camera, and foreground service use when
      present, without claiming that the repo-owned scripts publish directly to
      the store.

## 4. Verification
- [x] 4.1 Add or update targeted checks that prove the Android release
      packaging lane fails closed on missing/invalid signing, produces the
      intended signed upload artifact with checksum metadata, enforces the
      documented target SDK floor, and excludes repo-local debug assets from the
      AAB by content inspection.
- [x] 4.2 Run `openspec validate add-44-flow-4-release-verification-android-play-release-workflow --strict --no-interactive`.
