# Android Play Release

This runbook covers the repository-owned part of publishing the Android mobile
shell to Google Play. It prepares a signed Android App Bundle from the canonical
WSL checkout and stops before operator-owned Play Console submission work.

## Scope

The repository owns:
- release signing preflight
- Android App Bundle generation
- staged artifact layout
- local package inspection
- local Play-style split delivery inspection
- build metadata and SHA-256 checksum

The operator owns:
- Google Play App Signing enrollment choices
- release track selection
- store listing and contact details
- privacy policy and app-content declarations
- legal and policy review

## Signing Inputs

Release signing material stays outside the repository. Source the local upload
key environment before building:

```bash
source ~/.local/state/vk-turn-proxy-go/android-play-upload-key/relaydock-upload-20260426.env
```

The release workflow requires these variables:
- `VKTP_ANDROID_UPLOAD_KEYSTORE`
- `VKTP_ANDROID_UPLOAD_KEY_ALIAS`
- `VKTP_ANDROID_UPLOAD_STORE_PASSWORD`
- `VKTP_ANDROID_UPLOAD_KEY_PASSWORD`

The current Play-confirmed upload certificate is `relaydock-upload` with
SHA-256 fingerprint:

```text
74:30:5F:4E:67:81:FE:7A:81:93:7B:8C:EA:89:D5:A8:04:AC:7C:7C:7F:21:6B:27:18:A1:8E:EE:F0:D2:08:14
```

Do not commit the keystore, passwords, or copied signing config. The debug-key
ownership proof APK is not a release artifact.

## Build

Run the Play release entrypoint from the canonical WSL checkout:

```bash
make build-gui-android-play-release
```

The workflow:
1. validates the upload-key environment and keystore alias
2. synchronizes `publish_identity.json` and `version.json` derived assets
3. writes Linux-native Android `local.properties`
4. rebuilds the Android embedded host without packaged WireGuard seed assets
5. resolves the effective release `targetSdkVersion` through Gradle
6. enforces the repo-managed Play target SDK floor, currently API `35`
7. builds a signed release Android App Bundle
8. verifies the AAB contains the embedded host libraries
9. rejects packaged WireGuard seed assets such as
   `base/assets/wireguard/phone1.conf`
10. verifies the AAB signer matches the Play-confirmed upload certificate
11. downloads and verifies the pinned `bundletool-all` jar
12. builds Play-style APK splits from the AAB for a device spec
13. verifies the delivered split set contains the embedded host native
    libraries, excludes debug/proof assets, and retains JNI bridge callback
    method names required by the Android embedded host
14. stages artifact, checksum, and metadata

The local delivery verifier pins `bundletool-all` `1.18.1` by SHA-256:

```text
675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c
```

It caches the official jar under `dist/build/vendor/bundletool/` and writes the
generated `.apks` plus a verification report under
`dist/build/android-play-release-local-delivery/`.

To re-run the delivery check against an already staged AAB:

```bash
make verify-gui-android-play-release-local-delivery
```

By default the verifier uses a synthetic Android 14 arm64/ru/xxhdpi device
spec matching the published-launch recovery target class. To inspect a
connected phone exactly, pass its Linux ADB serial through the release build:

```bash
VKTP_ANDROID_PLAY_RELEASE_DEVICE_ID=7e4f6cab make build-gui-android-play-release
```

or call the verifier directly:

```bash
bash ./scripts/verify-android-play-release-local-delivery.sh --device-id 7e4f6cab
```

The staged output is:

```text
dist/mobile/android-play-release/app-release.aab
dist/mobile/android-play-release/app-release.aab.sha256
dist/mobile/android-play-release/build-metadata.json
```

The metadata records the effective target SDK and signing mode without storing
secrets.

## Play Console Handoff

After the staged AAB is ready, complete the operator-owned Console steps:
1. Confirm Play App Signing is enabled for `com.defin85.relaydock`.
2. Create an internal or closed testing release.
3. Upload `dist/mobile/android-play-release/app-release.aab`.
4. Resolve Play Console validation warnings before promoting the release.
5. Fill store listing text, icon, feature graphic, screenshots, support contact,
   and privacy policy URL. The current RelayDock privacy policy URL is
   `https://us-vmpico.shop/privacy-policy.html`.
6. Complete App content declarations: Data safety, content rating, target
   audience, ads, and app access.
   - Advertising ID: declare that RelayDock does not use an advertising ID.
     The release artifact does not declare
     `com.google.android.gms.permission.AD_ID`, and the app does not include an
     ads SDK or advertising ID client.
7. Review manifest-derived policy surfaces before submission:
   - `VpnService`
   - `QUERY_ALL_PACKAGES`
   - `CAMERA`
   - foreground service
   - network access and browser handoff behavior

This repository does not automate Play Console publication through the Google
Play Developer API.
