# Build Workflows

Use repo-owned scripts for reproducible local and CI builds instead of ad-hoc commands.
The canonical human-facing product version source for supported artifacts is `version.json` at the repository root.
Run `./scripts/sync-version-assets.py` when `version.json` changes so Flutter-facing defaults stay aligned during local development across desktop and mobile Flutter workspaces.

## Go artifacts from WSL

Build the default Go matrix from the canonical WSL checkout:

```bash
./scripts/build-go-matrix.sh
```

Build a narrower target set when needed:

```bash
./scripts/build-go-matrix.sh windows/amd64
```

Artifacts are staged under `dist/go/<goos>-<goarch>/`.
Repo-owned Go builds stamp product version, build number, revision, dirty state, build timestamp, and artifact role/target into the binaries.
The default matrix currently includes:
- `linux/amd64`
- `windows/amd64`

## Windows GUI from WSL

Windows Flutter desktop builds are host-bound and must run through a Windows-native toolchain.
The repository standardizes that path through a persistent mirror at `E:\Projects\vk-turn-proxy-go`.

Prerequisites:
- WSL checkout remains the canonical source tree.
- `E:\Projects` is mounted in WSL at `/mnt/e/Projects`.
- Windows has a compatible Flutter SDK version matching `desktop/gui_shell/.flutter-version`.
- Windows has the Visual Studio C++ desktop workload and Windows SDK required by `flutter build windows`.

Run the repo-owned wrapper from WSL:

```bash
./scripts/build-windows-gui-from-wsl.sh
```

That workflow:
1. cross-builds the required Windows Go sidecar artifacts from WSL
2. synchronizes the repository into `E:\Projects\vk-turn-proxy-go`
3. runs the native Windows GUI build from that mirrored path
4. stages the packaged bundle under `dist/windows-gui/`

The Windows GUI package includes a sibling `clientd.exe` next to `gui_shell.exe`.
The workflow also validates that `desktop/gui_shell/pubspec.yaml` matches `version.json` before packaging.
The WSL wrapper also writes `dist/build/windows-gui-build-metadata.json` so the mirrored native Windows build path can keep revision/dirty stamping even when the mirror does not include `.git`.

## Native Windows GUI build

When the mirror already exists at `E:\Projects\vk-turn-proxy-go`, run the Windows-native build script directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\build-gui-windows.ps1
```

The script fails closed if:
- it is run from a UNC path
- the pinned Flutter version is missing or mismatched
- `flutter doctor -v` does not confirm the required Windows desktop toolchain
- `dist\go\windows-amd64\clientd.exe` is missing
- `desktop\gui_shell\pubspec.yaml` does not match the canonical version in `version.json`

For the validated Windows desktop `WireGuard` PoC that keeps system VPN in the
external `WireGuard for Windows` client and uses the desktop shell only as the
local transport ingress, follow `docs/windows-desktop-wg-poc.md`.
That workflow also includes the repo-owned sidecar launch helper
`scripts/run-windows-gui-shell.ps1`.

## Mobile GUI shell local development

The first mobile shell is app-focused and now ships with a repo-owned Android packaged-host workflow.
The iOS side still has no native packaging workflow in this change.

Prerequisites:
- Flutter SDK version matches `mobile/gui_shell/.flutter-version`
- platform SDKs are installed locally when running on a real Android or iOS target
- `./scripts/sync-version-assets.py` has been run after any `version.json` change

Use the local verification path from the mobile workspace:

```bash
cd mobile/gui_shell
flutter analyze
flutter test
```

For development against an HTTP bridge:

```bash
cd mobile/gui_shell
flutter run --dart-define=VKTP_MOBILE_HOST_URL=http://127.0.0.1:7777
```

Without that override, the mobile shell requires the native platform layer to provide a host endpoint.
Android packaged builds start the bundled embedded host through that native bridge; the current iOS bridge resolves either `VKTMobileHostURL` or the local loopback development host.
Use these platform keys when packaging a specific bridged or embedded host endpoint:
- Android manifest meta-data: `com.defin85.vk_turn_proxy_go.MOBILE_HOST_URL`
- iOS `Info.plist`: `VKTMobileHostURL`

If native bridge discovery fails during app bootstrap, the shell now surfaces a blocked startup state inside the UI instead of crashing before the first frame.
If previously persisted secure state cannot be restored, use the in-app `Reset local state` recovery action before attempting to reconnect.
Android `main` packaging limits cleartext HTTP to the loopback bridge path; `debug` and `profile` overlays keep broader cleartext enabled for explicit development bridge overrides.

## Android GUI packaging from WSL

The Android packaged-host workflow is standardized through the Windows mirror at `E:\Projects\vk-turn-proxy-go`.

Run the repo-owned wrapper from WSL:

```bash
bash ./scripts/build-android-gui-from-wsl.sh
```

That workflow:
1. synchronizes Flutter version assets from `version.json`
2. mirrors the repository into `E:\Projects\vk-turn-proxy-go`
3. rebuilds the packaged Android embedded host in the mirror
4. writes Windows-native `android/local.properties` with the active Android SDK and Flutter SDK roots
5. builds the debug APK through the pinned Windows Flutter SDK with stamped build identity
6. validates that the APK contains the packaged JNI and embedded-host `.so` files
7. stages the final APK under `dist/mobile/android-gui-shell/`

The staged directory includes:
- `app-debug.apk`
- `app-debug.apk.sha1`
- `build-metadata.json`

For a repo-owned smoke of the packaged-host shared-library path reaching control-plane `ready` without an external `clientd` or `VKTP_MOBILE_HOST_URL`:

```bash
make smoke-android-embedded-host
```

For the validated physical-device Android PoC that keeps device-wide VPN in the
external `WireGuard` app and uses the packaged mobile shell only as the local
transport ingress, follow `docs/android-wg-phone-poc.md`.

## Native Android GUI build

When the mirror already exists at `E:\Projects\vk-turn-proxy-go`, run the Windows-native build script directly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\build-gui-android.ps1
```

The native script fails closed if:
- it is run from a UNC path
- the pinned Flutter version is missing or mismatched
- `flutter doctor -v` does not confirm the Android toolchain
- the Android embedded host build fails
- the final APK does not contain the packaged `libvk_turn_mobile_host.so` and `libandroid_mobile_host_jni.so` entries

For ad-hoc native Android packaging smoke on Windows when the mirror exists at `E:\Projects\vk-turn-proxy-go`:

```powershell
cd E:\Projects\vk-turn-proxy-go\mobile\gui_shell
flutter pub get
flutter build apk --debug
```

## Local entrypoints

From the repository root:

```bash
make build-go
make build-gui-windows
make build-gui-android
make sync-version-assets
```

`make ci` remains the fast Go-only smoke path.

## CI

The repository uses the same repo-owned scripts in CI:
- Ubuntu runners use the Go build/test entrypoints
- Windows runners build the GUI through `scripts/build-gui-windows.ps1`
