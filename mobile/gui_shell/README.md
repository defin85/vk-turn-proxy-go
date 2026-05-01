# Mobile GUI Shell

`mobile/gui_shell` is the first Flutter mobile shell for `vk-turn-proxy-go`.
It is an app-owned shell over the local client-control semantics, not a second
runtime contract.

## Scope

- manage saved profiles inside the mobile app
- transfer saved profiles across shells through explicit portable-profile
  share/file/QR actions
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
./scripts/sync-publish-identity.py
./scripts/sync-version-assets.py
dart pub get
cd mobile/gui_shell
flutter analyze
flutter test
flutter run -d <android-device>
```

The pinned Flutter SDK version for this project is stored in `mobile/gui_shell/.flutter-version`.
The canonical product version source remains `version.json` at the repository root.
The canonical publish-facing native identifier source is `publish_identity.json` at the repository root.
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
4. builds the debug APK with the pinned Flutter SDK
5. validates that the APK contains the packaged JNI and embedded-host `.so` files
6. rejects packaged WireGuard seed assets; Android WireGuard runtime material
   must be configured explicitly at runtime rather than hidden in the APK
7. stages the result under `dist/mobile/android-gui-shell/`

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

The smoke creates a structured `wireguard_native_v1` profile inside the
packaged host, starts the RelayDock-owned Android `VpnService`, verifies the
active VPN owner through `dumpsys connectivity`, disconnects through the
RelayDock platform-tunnel API, and verifies the app no longer owns the VPN.
It defaults to preserving the active local network route so ADB-over-Wi-Fi
remains reachable during the check.

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
The current RelayDock package/bundle cutover is still documented as a
fresh-install or reinstall boundary for ordinary mobile shell state and secure
storage. Do not present it as an in-place continuity path unless a reviewed
migration mechanism ships later.

Portable profile transfer is a separate explicit path.
The app does not persist portable-profile envelopes as ordinary shell state,
and it does not substitute portable transfer for runtime handoff export.

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
- `Routing`: a dedicated searchable route for app-routing modes and
  platform-tunnel status; shown as a primary rail destination on
  wider layouts and opened as an explicit compact workflow on phones. It may
  link to VPN transport profile setup, but profile/runtime defaults editing
  stays in `Profiles`, and the primary VPN connect/disconnect toggle stays on
  `Home`.

Advanced runtime overrides and secondary resolution/session actions stay
reachable through explicit disclosure and overflow affordances instead of
crowding the first mobile screen.

## Interaction surface taxonomy

`mobile/gui_shell` classifies surfaces by task weight rather than by widget
habit:

- bottom sheets for local, reversible choices inside the current workflow
- dedicated follow-on routes for catalog or library flows that need search,
  tabs, longer lists, or multiple actions
- dialog-sized overlays for compact preview, confirmation, and short status
  summaries that do not become the main browsing surface

Current mobile surface map:

- `Routing profile` and `App scope`: bottom-sheet local pickers
- `New provider`: dedicated follow-on route from `Providers`
- owned-browser continuation: full-screen route
- portable import/export preview: dialog-sized overlay
- compact host/status summary: dialog-sized overlay

## Portable profile transfer

The `Profiles` workflow now supports explicit shell-to-shell transfer of saved
profiles:

- `Export saved profile` builds one shared portable-profile envelope from the
  saved profile plus any managed-provider snapshot required to reopen it in the
  same managed/custom source mode on another shell
- from that same envelope, the mobile shell can copy text, share text, share a
  `.json` file, and render QR when the encoded payload fits the shared QR
  bounds
- if the payload is too large for QR, the shell fails closed for QR and keeps
  non-QR export available instead of generating a partial QR
- mobile import currently accepts a selected file, a shared or opened portable
  profile `.json` file from the OS, pasted envelope text, or a scanned QR
  payload, always shows a preview before confirmation, allocates fresh local
  ids, restores managed-provider bindings from the embedded snapshot, and never
  auto-connects, auto-resolves, or silently overwrites an existing local
  profile
- secret-bearing portable envelopes are warned explicitly before share, copy,
  QR rendering, or import confirmation

This path is intentionally separate from the existing copy/share actions on a
resolved handoff artifact.
Runtime handoff export still transfers a short-lived resolved runtime secret,
while portable profile transfer moves a saved profile workspace snapshot for
another shell.

## Lifecycle and browser handoff

The shell is app-owned and mobile-aware:

- app resume triggers a reconnect or refresh attempt
- browser challenges stay on the platform browser handoff path by default
- challenges that advertise `owned_browser_observed` open in an app-owned
  embedded WebView instead of the external browser and continue with the
  documented cookie-backed payload from that same in-app session
- when that typed challenge metadata also approves remembered sign-in, the
  shell reuses the same app-owned WebView browser sandbox across compatible
  embedded challenge opens on the same install instead of clearing it on every
  open and close
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
If remembered browser state still exists but no longer proves completion for
the current challenge, the shell also fails closed and keeps the manual
continuation fallback explicit instead of treating remembered sign-in as proof.

Remembered embedded sign-in has its own reset path.
The `Support` surface exposes `Forget embedded sign-in`, which clears the
app-owned embedded browser cookies and browser-backed storage without wiping
saved profiles, provider drafts, routing preferences, or unrelated shell
preferences.

The current repo-owned approval gate is narrow by design:

- Android embedded host upgrades only approved provider flows to
  `owned_browser_observed`
- the shipped approval list currently covers the `vk` provider when the
  challenge exposes browser-owned stage requests or the committed
  browser-observed authenticated hosted-call contour
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
