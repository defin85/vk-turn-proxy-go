# Mobile GUI Shell

`mobile/gui_shell` is the first Flutter mobile shell for `vk-turn-proxy-go`.
It is an app-owned shell over the local client-control semantics, not a second
runtime contract.

## Scope

- manage saved profiles inside the mobile app
- persist non-secret profile metadata and runtime defaults while clearing
  provider input links from persisted shell state
- connect to a compatible embedded or bridged mobile host
- start and stop sessions through that mobile host bridge
- start and stop typed platform tunnels, including packaged Android
  `android_vpn_service` startup when the host advertises that mode
- present a VPN-first `Home / Profiles / Providers / Support` shell, with `Routing` as a
  dedicated mode-aware workflow instead of a permanently promoted phone tab
- surface typed session state, challenge state, and diagnostics export
- export resolved provider handoffs through explicit copy/share actions for another device
- hand browser-oriented provider challenges off through platform-native URL launching

## Non-goals for this slice

- iOS Network Extension integration
- unsupported or implicit platform-tunnel startup outside the host-advertised
  typed `platform_tunnels` contract
- provider-specific mobile UI logic beyond typed challenge orchestration

For the operator-validated Android PoC that keeps device-wide VPN in an
external `WireGuard` app instead of the packaged `VpnService` path, see
`docs/android-wg-phone-poc.md`.

## Local development

From the repository root:

```bash
./scripts/sync-version-assets.py
dart pub get
cd mobile/gui_shell
flutter analyze
flutter test
flutter run -d <android-device>
```

The pinned Flutter SDK version for this project is stored in `mobile/gui_shell/.flutter-version`.
The canonical product version source remains `version.json` at the repository root.
The repository-root Dart workspace owns dependency resolution for this shell: keep using the root `pubspec.lock`, and rerun `dart pub get` from the repo root after dependency changes or a fresh checkout.
The primary Android debug loop now assumes a Linux Android SDK/NDK inside WSL plus a physical device connected through `adb` from WSL, rather than the Windows mirror or an Android emulator.

## Host bridge contract

The mobile shell expects a compatible bridge that satisfies the same client-control semantics as `cmd/clientd` and `pkg/clientcontrol`.
Required capabilities for the first slice are:

- `mobile_host_bridge`
- `platform_tunnels`
- `profiles`
- `provider-runtime-artifacts`
- `runtime-execution-planning`
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
When the host also advertises `runtime-execution-planning`, host-owned same-device actions and platform-tunnel reports expose typed execution plans instead of one implicit mobile VPN mode.
Current repo-owned mobile startup still defaults to the documented TURN-backed `custom_packet_overlay` plan for ordinary host-owned sessions, while packaged Android `VpnService` startup is now implemented as the first supported TURN-backed `wireguard_native` platform-tunnel path.
Apple Network Extension planning remains explicitly scoped but unavailable until that host adapter ships.
The mobile shell renders that report in-app and uses the typed `/v1/platform-tunnels/start` result instead of guessing device-wide tunnel support from the OS alone.
Operators can request startup for the reported mode directly from the shell and now get the documented packaged Android `ready=true` path when the host reports `android_vpn_service` as supported.

## Android packaging

From the repository root on WSL, build the packaged Android app with the Linux-native SDK/NDK path:

```bash
make build-gui-android
```

That workflow:
1. uses the Linux Android SDK/NDK from WSL
2. rebuilds the packaged Android embedded host in-place
3. writes Linux-native `android/local.properties`
4. optionally stages the local Android WireGuard dev profile from
   `VKTP_ANDROID_WIREGUARD_PROFILE` or
   `~/.local/state/vk-turn-proxy-go/wg/phone1.conf` into the debug APK assets
   for the packaged `android_vpn_service` dev path
5. builds the debug APK with the pinned Flutter SDK
5. validates that the APK contains the packaged JNI and embedded-host `.so` files
6. stages the result under `dist/mobile/android-gui-shell/`

The WSL shell environment should expose:

- `ANDROID_HOME` / `ANDROID_SDK_ROOT`
- `JAVA_HOME`
- `platform-tools`, `cmdline-tools/latest/bin`, and the required `build-tools` on `PATH`

The current repo-owned setup expects the Linux Android SDK at `~/.local/share/android-sdk`.

For a repo-owned smoke that proves the packaged-host shared-library path reaches `ready` without an external `clientd` or `VKTP_MOBILE_HOST_URL`:

```bash
make smoke-android-embedded-host
```

For a repo-owned physical-device smoke that proves the packaged
`android_vpn_service` path can return `ready=true`:

```bash
TURN_LINK='generic-turn://...' make smoke-android-vpn-service
```

For a Windows-native build from the mirror:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\build-gui-android.ps1
```

For the older WSL wrapper that still mirrors into `E:\Projects\vk-turn-proxy-go`, use:

```bash
make build-gui-android-windows-mirror
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
The primary product shell is now split into:

- `Home`: selected profile or empty state, current mode, scope summary,
  compact live status, and one dominant connect or disconnect action
- `Profiles`: saved profile selection, add, import, and edit entry points
- `Providers`: saved managed provider records first, with explicit blank or
  template-backed new-provider flows instead of a preset-heavy root
- `Support`: activity and diagnostics drill-down without making those surfaces
  the default first impression
- `Routing`: a dedicated searchable route for app-routing modes; shown as a
  primary rail destination on wider layouts and opened as an explicit compact
  workflow on phones

Advanced runtime overrides and secondary resolution/session actions stay
reachable through explicit disclosure and overflow affordances instead of
crowding the first mobile screen.

## Lifecycle and browser handoff

The shell is app-owned and mobile-aware:

- app resume triggers a reconnect or refresh attempt
- browser challenges stay on the platform browser handoff path by default
- challenges that advertise `owned_browser_observed` open in an app-owned
  embedded WebView instead of the external browser and continue with the
  documented cookie-backed payload from that same in-app session
- app-return-compatible challenges may auto-continue once when the app receives
  the documented foreground-resume or native browser-return signal for that
  active challenge
- the operator can still explicitly confirm completion with `I've completed it`
  when automatic continuation is unavailable, ambiguous, or insufficient

Current repo-owned VK challenge metadata advertises the documented
foreground-resume path for that one-shot auto-continue policy.
Returning from the browser remains a continuation hint rather than proof that
provider resolution succeeded, so the manual fallback action stays available.

Owned browser continuation is fail-closed.
If the host does not advertise `owned_browser_observed`, if the challenge omits
the documented cookie domains, or if the embedded WebView session cannot return
cookies for those domains, the shell cancels that active challenge through the
host bridge instead of silently claiming success or inventing a fallback path.

The current repo-owned approval gate is narrow by design:

- Android embedded host upgrades only approved provider flows to
  `owned_browser_observed`
- the shipped approval list currently covers the `vk` provider only when the
  challenge also exposes browser-owned stage requests
- other providers and hosts remain on the documented system-browser path unless
  they explicitly advertise the owned-browser mode through the typed challenge
  contract

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
