# Mobile GUI Shell

`mobile/gui_shell` is the first Flutter mobile shell for `vk-turn-proxy-go`.
It is an app-owned shell over the local client-control semantics, not a second runtime contract and not a claim of device-wide VPN or tunnel integration.

## Scope

- manage saved profiles inside the mobile app
- persist non-secret profile metadata and runtime defaults while clearing
  provider input links from persisted shell state
- connect to a compatible embedded or bridged mobile host
- start and stop sessions through that mobile host bridge
- surface typed session state, challenge state, and diagnostics export
- export resolved provider handoffs through explicit copy/share actions for another device
- hand browser-oriented provider challenges off through platform-native URL launching

## Non-goals for this slice

- Android `VpnService` or iOS Network Extension integration
- device-wide capture or route management
- provider-specific mobile UI logic beyond typed challenge orchestration

For the current operator-validated Android PoC that keeps device-wide VPN in an
external `WireGuard` app and uses this shell only as the local transport
ingress, see `docs/android-wg-phone-poc.md`.

## Local development

From the repository root:

```bash
./scripts/sync-version-assets.py
dart pub get
cd mobile/gui_shell
flutter analyze
flutter test
flutter run -d android
```

The pinned Flutter SDK version for this project is stored in `mobile/gui_shell/.flutter-version`.
The canonical product version source remains `version.json` at the repository root.
The repository-root Dart workspace owns dependency resolution for this shell: keep using the root `pubspec.lock`, and rerun `dart pub get` from the repo root after dependency changes or a fresh checkout.

## Host bridge contract

The mobile shell expects a compatible bridge that satisfies the same client-control semantics as `cmd/clientd` and `pkg/clientcontrol`.
Required capabilities for the first slice are:

- `mobile_host_bridge`
- `platform_tunnels`
- `profiles`
- `provider-runtime-artifacts`
- `sessions`
- `challenges`
- `diagnostics`
- `event_stream`

By default, the app resolves the control-plane endpoint through a native platform bridge.
On Android packaged builds, that native bridge now starts and returns the bundled embedded host by default.
On iOS, the current native bridge resolves either `VKTMobileHostURL` or the local loopback development host.
Platform packaging can override that endpoint with:

- Android manifest meta-data: `com.defin85.vk_turn_proxy_go.MOBILE_HOST_URL`
- iOS `Info.plist`: `VKTMobileHostURL`

For explicit development overrides, the Flutter app can still talk to an HTTP bridge by supplying:

```bash
flutter run --dart-define=VKTP_MOBILE_HOST_URL=http://127.0.0.1:7777
```

If the bridge is missing or incompatible, the app fails closed for session control and reports that state explicitly instead of pretending tunnel support exists.
If native bridge discovery fails during startup, the shell stays blocked in-app and reports that resolver error instead of crashing before the first screen.
On Android, default/release packaging keeps cleartext HTTP limited to the local bridge path, while `debug` and `profile` variants keep broader cleartext enabled for explicit development bridge overrides.
Host metadata may also include a typed `platform_tunnels` report for `android_vpn_service` or `apple_network_extension`.
The mobile shell renders that report in-app and uses the typed `/v1/platform-tunnels/start` result instead of guessing device-wide tunnel support from the OS alone.
Operators can request startup for the reported mode directly from the shell to inspect the stage-aware fail-closed result before any future platform host claims support.
Current repo-owned mobile hosts still fail closed for those modes until an Android `VpnService` or Apple Network Extension path is implemented inside the native host boundary.

## Android packaging

From the repository root on WSL, build the packaged Android app with:

```bash
bash ./scripts/build-android-gui-from-wsl.sh
```

That wrapper mirrors the repository into `E:\Projects\vk-turn-proxy-go`, rebuilds the embedded Android host, writes Windows-native `android/local.properties`, builds the debug APK with the pinned Flutter SDK, and stages the result under `dist/mobile/android-gui-shell/`.

For a repo-owned smoke that proves the packaged-host shared-library path reaches `ready` without an external `clientd` or `VKTP_MOBILE_HOST_URL`:

```bash
make smoke-android-embedded-host
```

For a Windows-native build from the mirror:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\build-gui-android.ps1
```

## Local state

The shell persists:

- saved profiles
- the selected profile
- the in-progress draft

Persisted shell state keeps only non-secret metadata.
Provider input links are cleared before preferences are written, so invite URLs,
room/bootstrap tokens, and `generic-turn://...` credentials do not survive app
restart as persisted shell state.
The mobile store still keeps a fail-closed migration guard for older installs
that referenced secure-only link state; if that legacy secure payload is
missing, the operator must use `Reset local state` before reconnecting.

## Workflow-first navigation

The mobile shell no longer treats every surface as one long dashboard.
The primary phone flow is now split into three destinations:

- `Workflow`: compact host/tunnel summary plus profile selection, editing,
  save, resolve, and start actions
- `Activity`: mobile-sized resolutions and sessions surfaces
- `Diagnostics`: detailed host state, platform-tunnel reporting, and event
  stream

Advanced runtime overrides, provider-specific settings, and secondary
resolution/session actions stay reachable through explicit disclosure and
overflow affordances instead of crowding the first mobile screen.

## Lifecycle and browser handoff

The shell is app-owned and mobile-aware:

- app resume triggers a reconnect or refresh attempt
- browser challenges are opened through the platform browser handoff path
- app-return-compatible challenges may auto-continue once when the app receives
  the documented foreground-resume or native browser-return signal for that
  active challenge
- the operator can still explicitly confirm completion with `I've completed it`
  when automatic continuation is unavailable, ambiguous, or insufficient

Current repo-owned VK challenge metadata advertises the documented
foreground-resume path for that one-shot auto-continue policy.
Returning from the browser remains a continuation hint rather than proof that
provider resolution succeeded, so the manual fallback action stays available.

## Diagnostics

Diagnostics export writes JSON bundles under the app documents directory in `diagnostics/`.
Each bundle includes:

- typed session snapshot
- recent events
- active challenges
- metrics text
- GUI build identity
- host build identity
- control-plane contract version
