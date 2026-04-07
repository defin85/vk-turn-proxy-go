# Mobile GUI Shell

`mobile/gui_shell` is the first Flutter mobile shell for `vk-turn-proxy-go`.
It is an app-owned shell over the local client-control semantics, not a second runtime contract and not a claim of device-wide VPN or tunnel integration.

## Scope

- manage saved profiles inside the mobile app
- persist provider/runtime secrets through platform-native secure storage
- connect to a compatible embedded or bridged mobile host
- start and stop sessions through that mobile host bridge
- surface typed session state, challenge state, and diagnostics export
- hand browser-oriented provider challenges off through platform-native URL launching

## Non-goals for this slice

- Android `VpnService` or iOS Network Extension integration
- device-wide capture or route management
- provider-specific mobile UI logic beyond typed challenge orchestration

## Local development

From the repository root:

```bash
./scripts/sync-version-assets.py
cd mobile/gui_shell
flutter analyze
flutter test
flutter run -d android
```

The pinned Flutter SDK version for this project is stored in `mobile/gui_shell/.flutter-version`.
The canonical product version source remains `version.json` at the repository root.

## Host bridge contract

The mobile shell expects a compatible bridge that satisfies the same client-control semantics as `cmd/clientd` and `pkg/clientcontrol`.
Required capabilities for the first slice are:

- `mobile_host_bridge`
- `profiles`
- `sessions`
- `challenges`
- `diagnostics`
- `event_stream`

During development, the Flutter app can talk to an HTTP bridge by supplying:

```bash
flutter run --dart-define=VKTP_MOBILE_HOST_URL=http://127.0.0.1:7777
```

If the bridge is missing or incompatible, the app fails closed for session control and reports that state explicitly instead of pretending tunnel support exists.

## Secure storage

The shell persists:

- saved profiles
- the selected profile
- the in-progress draft

Non-secret profile state stays in general app preferences.
Runtime secrets such as invite links and TURN overrides are stored separately through platform-native secure storage.

## Lifecycle and browser handoff

The shell is app-owned and mobile-aware:

- app resume triggers a reconnect or refresh attempt
- browser challenges are opened through the platform browser handoff path
- the operator explicitly confirms completion with `I've completed it`

That explicit confirmation keeps the current mobile slice honest: returning from the browser is a hint, not proof that the provider challenge completed successfully.

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
