# Build Workflows

Use repo-owned scripts for reproducible local and CI builds instead of ad-hoc commands.
The canonical human-facing product version source for supported artifacts is `version.json` at the repository root.
The canonical publish-facing package, bundle, and application identifier source is `publish_identity.json` at the repository root.
Run `./scripts/sync-publish-identity.py` when `publish_identity.json` changes so native packaging surfaces and package-oriented automation stay aligned.
Run `./scripts/sync-version-assets.py` when `version.json` changes so Flutter-facing defaults stay aligned during local development across desktop and mobile Flutter workspaces.

## Flutter workspace resolution

Flutter shell development now uses an explicit repository-root Dart workspace with these members:
- `desktop/gui_shell`
- `mobile/gui_shell`
- `packages/flutter_shell_core`

Run the public resolution step from the repository root before shell-local `flutter analyze`, `flutter test`, `flutter run`, or `flutter build` commands:

```bash
dart pub get
```

Use this follow-up command when you need to inspect the active workspace membership:

```bash
dart pub workspace list
```

The authoritative resolution artifacts are the root `pubspec.lock` and root `.dart_tool/package_config.json`.
Do not rely on `flutter pub get` inside individual shell app directories as the primary workflow.

## Flutter UI development via Dart MCP

For day-to-day UI development, prefer Dart MCP over ad-hoc `flutter run` terminals.

Rules:
- Use `mcp__dart_mobile__` for `mobile/gui_shell` and `mcp__dart_desktop__` for `desktop/gui_shell`. Keep `mcp__dart__` only as a backward-compatible single-target fallback.
- `launch_app.root` must be a plain filesystem path such as `/home/egor/code/vk-turn-proxy-go/mobile/gui_shell`.
- Do not pass `file://...` URIs to `launch_app.root`.
- Always launch agent-operated Dart MCP app sessions with a driver-extension entrypoint. Use `target="test_driver/driver_main.dart"` for the normal desktop and mobile shells so `flutter_driver` health checks, screenshots, taps, and text automation are available.
- Each Dart MCP namespace currently supports one active Dart Tooling Daemon connection at a time.
- With dedicated namespaces, one Codex session can keep separate desktop and mobile DTD connections. Use a fresh session only when replacing an already connected target inside the same namespace.
- Do not switch to `adb`-driven install/logcat/forward/input work unless the user explicitly agrees to that fallback in the current thread.

Verified mobile loop:
1. `dart pub get`
2. `mcp__dart_mobile__.launch_app(device="<adb-serial>", root="/home/egor/code/vk-turn-proxy-go/mobile/gui_shell", target="test_driver/driver_main.dart")`
3. `mcp__dart_mobile__.connect_dart_tooling_daemon(uri="<returned dtd uri>")`
4. `mcp__dart_mobile__.hot_reload`
5. `mcp__dart_mobile__.flutter_driver(command="screenshot")`

Verified USB alternative from WSL:
1. In elevated Windows PowerShell, run `usbipd bind --busid <busid>` once for
   the Android ADB interface when needed.
2. In Windows PowerShell, keep `usbipd attach --wsl --busid <busid> --auto-attach`
   running while the USB debug session is active.
3. In WSL, confirm `adb devices -l` shows a USB serial.
4. Use that USB serial in `mcp__dart_mobile__.launch_app(...)` instead of the Wi-Fi
   ADB target.

On this workstation, the verified USB path also requires a `udev` rule for the
tablet's ADB interface so Linux `adb` can open the USB node without a manual
permission fix. See `DEBUG.md` for the exact verified rule and workstation
notes.

Do not omit the driver-extension target unless the user explicitly asks for a production-entrypoint parity run and accepts that Flutter Driver screenshots/taps will be unavailable for that run.

Verified desktop Linux launch path:
1. `dart pub get`
2. `go run ./cmd/clientd -listen 127.0.0.1:7777`
3. `mcp__dart_desktop__.launch_app(device="linux", root="/home/egor/code/vk-turn-proxy-go/desktop/gui_shell", target="test_driver/driver_main.dart")`
4. `mcp__dart_desktop__.connect_dart_tooling_daemon(uri="<returned dtd uri>")`
5. Use `mcp__dart_desktop__.hot_reload` and `mcp__dart_desktop__.flutter_driver(command="screenshot")` from that desktop namespace

The authoritative verified notes for this workflow live in `DEBUG.md`.

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

## Ubuntu Linux GUI package

The first supported Linux `linux_tun` desktop target is the repo-owned Ubuntu
package staged by:

```bash
make build-gui-linux
```

That workflow:
1. synchronizes publish and version metadata
2. verifies the pinned Flutter Linux desktop toolchain
3. builds the Linux Go sidecar artifacts
4. builds the desktop Flutter Linux bundle
5. stages the GUI, sibling unprivileged `clientd` launcher, real
   `libexec/clientd`, privileged `libexec/relaydock-linux-tun-helper`, desktop
   entry, hicolor app icon, helper-only polkit action, installer, and build
   metadata under `dist/linux-gui/`

Install the staged package on the documented Ubuntu target with:

```bash
sudo dist/linux-gui/install-ubuntu.sh
```

Build an installable Debian package from the staged Ubuntu package with:

```bash
make package-gui-linux-deb
```

That workflow reads `dist/linux-gui/`, then stages
`dist/linux-deb/relaydock_<version>-<build>_amd64.deb` plus a `.sha256`
checksum. The `.deb` installs the same `/opt/relaydock` payload, desktop entry,
hicolor icon, helper-only polkit action, and operator-user transport-profile
store behavior as the scripted Ubuntu installer.

The installed package lives under `/opt/relaydock`.
The desktop GUI discovers the sibling `clientd` launcher, which starts
`libexec/clientd` as the operator user with `VKTP_LINUX_PACKAGED_TARGET=ubuntu`.
Raw `go run` or hand-copied bundles must keep `linux_tun` unavailable. Privilege
mediation is helper-only: `pkexec` may execute
`/opt/relaydock/libexec/relaydock-linux-tun-helper` only during a `linux_tun`
startup attempt, never for ordinary local-host startup.
The installer also places `com.defin85.relaydock.desktop` and the hicolor
`com.defin85.relaydock` icon into the desktop environment so launchers and docks
resolve the packaged RelayDock icon instead of stale local entries.
Use `docs/linux-desktop-tun-package.md` for the support-promotion runbook and
verification bar.

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

The Windows GUI package includes sibling `clientd.exe` and `wintun.dll`
artifacts next to `RelayDock.exe`.
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

For the verified repo-owned Windows `windows_wintun` ready path, follow
`docs/windows-desktop-wg-poc.md`.
That runbook covers the VMware-backed execution cell, the guest sync helper
`scripts/sync-windows-vm-lab.sh`, the guest launcher
`run-vm-lab-shell.ps1`, the guest host preflight
`assert-vm-lab-host.ps1`, and the packaged-host `ready=true` smoke
`smoke-windows-wintun.ps1`.
The bundled host reports `windows_wintun available=true` only when the
documented strict local WireGuard materializer prerequisite is present, so the
runbook keeps that prerequisite explicit instead of implying a generic Windows
support bit.

For the packaged Windows desktop workflow that starts from a real VK invite in
the GUI, moves through typed resolution and browser continuation when needed,
and then starts the same-device desktop session, follow
`docs/windows-desktop-live-vk-workflow.md`.

## Mobile GUI shell local development

The first mobile shell is app-focused and now ships with a repo-owned Android packaged-host workflow.
The iOS side still has no native packaging workflow in this change.

Prerequisites:
- Flutter SDK version matches `mobile/gui_shell/.flutter-version`
- platform SDKs are installed locally when running on a real Android or iOS target
- `./scripts/sync-publish-identity.py` has been run after any
  `publish_identity.json` change
- `./scripts/sync-version-assets.py` has been run after any `version.json` change

Use the local verification path from the mobile workspace:

```bash
dart pub get
cd mobile/gui_shell
flutter analyze
flutter test
```

When the user has explicitly agreed to an `adb` fallback for physical-device
work, keep a Linux Android SDK/NDK inside WSL and target the device through
Linux `adb` rather than depending on a Windows-hosted emulator. The current
repo-owned setup expects that SDK root at `~/.local/share/android-sdk`.

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

The primary Android packaged-host workflow is now Linux-native from the WSL
checkout.

Run the repo-owned build entrypoint from WSL:

```bash
make build-gui-android
```

That workflow:
1. synchronizes publish-facing package and bundle identifiers from
   `publish_identity.json`
2. synchronizes Flutter version assets from `version.json`
3. rebuilds the packaged Android embedded host against the Linux Android NDK in
   WSL
4. writes Linux-native `android/local.properties` with the active Android SDK
   and Flutter SDK roots
5. builds the debug APK through the pinned Linux Flutter SDK with stamped build
   identity
6. stages the final APK under `dist/mobile/android-gui-shell/`
7. validates that the APK contains the packaged JNI and embedded-host `.so`
   files
8. rejects packaged WireGuard seed assets; Android WireGuard runtime material
   must be configured explicitly at runtime rather than hidden in the APK

The staged directory includes:
- `app-debug.apk`
- `app-debug.apk.sha1`
- `build-metadata.json`

The Linux Android SDK/NDK path currently required by the repo-owned scripts is:

- `platform-tools`
- `platforms;android-36`
- `build-tools;36.0.0`
- `cmake;3.22.1`
- `ndk;28.2.13676358`

Because the canonical Android package is now `com.defin85.relaydock`, treat any
older `com.defin85.mobile_gui_shell` installation as a legacy package cleanup
case instead of an in-place upgrade target.

For a repo-owned smoke of the packaged-host shared-library path reaching control-plane `ready` without an external `clientd` or `VKTP_MOBILE_HOST_URL`:

```bash
make smoke-android-embedded-host
```

For the repo-owned physical-device smoke that proves the packaged
`android_vpn_service` path can reach `ready=true` on a connected Android
device, use:

```bash
TURN_LINK='generic-turn://...' make smoke-android-vpn-service
```

Optional environment and args:

- `ANDROID_SERIAL=<adb-serial>` when more than one device is connected
- after explicit user agreement to use `adb`, the repo-owned helpers default to Linux `adb` from `PATH` or
  `~/.local/share/android-sdk/platform-tools/adb` inside WSL
- `ADB=/mnt/c/Users/Egor/AppData/Local/Android/Sdk/platform-tools/adb.exe` to
  force the Windows adb binary for Windows-specific workflows
- `python3 ./scripts/smoke-android-vpn-service.py --policy allowed_packages --allowed-package com.google.android.youtube`
  to verify the typed per-app path instead of `all_apps`

When the Linux Android toolchain is unavailable or a Windows-native packaging
comparison is needed, the previous mirror workflow remains available:

```bash
make build-gui-android-windows-mirror
```

## Android Play release from WSL

Google Play publication uses a separate release lane from the debug APK
workflow above. The release lane stages a signed Android App Bundle and keeps
debug-only workstation assets out of the store-target package.

Source the operator-owned upload-key environment, then run:

```bash
source ~/.local/state/vk-turn-proxy-go/android-play-upload-key/relaydock-upload-20260426.env
make build-gui-android-play-release
```

That workflow stages:
- `dist/mobile/android-play-release/app-release.aab`
- `dist/mobile/android-play-release/app-release.aab.sha256`
- `dist/mobile/android-play-release/build-metadata.json`

The workflow fails closed when release signing inputs are missing, when the
effective release `targetSdkVersion` is below the documented Play floor, or when
the staged AAB contains packaged WireGuard seed assets such as
`base/assets/wireguard/phone1.conf`. It also runs a pinned `bundletool-all`
local delivery verifier, which builds device-targeted APK splits from the AAB
and checks the delivered native libraries, forbidden release assets, and JNI
bridge callback method names.

To re-run only the local delivery check against an existing staged AAB:

```bash
make verify-gui-android-play-release-local-delivery
```

Follow `docs/android-play-release.md` for the full signing contract, local
verification path, and operator-owned Google Play Console handoff.

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
cd E:\Projects\vk-turn-proxy-go
dart pub get
cd .\mobile\gui_shell
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
- `.github/workflows/release-artifacts.yml` can be run manually to upload the
  Android debug APK, Windows `RelayDock.exe` bundle zip, and Ubuntu `.deb`
  package as GitHub Actions artifacts
- the same workflow also creates or updates a GitHub Release on `v*` tag pushes
  and attaches those APK/ZIP/DEB artifacts to the release
