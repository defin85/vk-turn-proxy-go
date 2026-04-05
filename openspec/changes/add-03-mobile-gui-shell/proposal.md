# Change: [03] Add mobile GUI shell

## Why
Mobile users need a first-party client shell, but mobile lifecycle and entitlement constraints make it a different delivery slice from desktop.
The first mobile slice should deliver a coherent app shell and embedded host integration before system-wide tunnel behavior is added.

## Sequence
- Order: `03`
- Depends on: `add-01-client-control-plane`
- Unblocks: `add-05-platform-tunnel-integrations`

## What Changes
- Add a mobile GUI shell that manages profiles, sessions, challenges, and diagnostics through an embedded host integration.
- Define mobile-safe lifecycle behavior for Android and iOS without claiming full system tunnel support yet.
- Use platform-native secure storage and system-browser-oriented challenge handoff.

## Impact
- Affected specs: `mobile-gui-client`
- Affected code: future mobile app workspace, host bridge, secure storage integration, mobile docs
