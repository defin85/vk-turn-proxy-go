# Change: [14] Add Android embedded mobile host

## Why
The first mobile GUI slice is now real enough to run on Android devices, but production installs still block because the app does not actually ship a compatible local host.
An operator-facing Android app cannot depend on an external desktop-style `clientd`, a development loopback bridge, or a runtime binary download path.

## Sequence
- Order: `14`
- Depends on: `add-01-client-control-plane`, `add-03-mobile-gui-shell`, `add-09-native-build-workflows`, `add-11-build-version-surfacing`
- Unblocks: production-ready Android client delivery, later `add-05-platform-tunnel-integrations`

## What Changes
- Define an app-owned Android embedded host/runtime that ships inside the Android package and satisfies the existing mobile host semantics without an external `clientd`.
- Define how the Android app starts, versions, and supervises that embedded host while keeping the GUI and packaged host in one release unit.
- Keep the current external HTTP bridge path as an explicit development override, not the default production runtime model.
- Define packaging, ABI, lifecycle, and verification expectations for the Android host slice without claiming `VpnService` or device-wide tunnel capture yet.

## Impact
- Affected specs: `mobile-gui-client`, `android-embedded-mobile-host`
- Affected code: future Android host runtime module, native library packaging, Android service/process glue, mobile bridge implementation, build workflows, mobile docs
