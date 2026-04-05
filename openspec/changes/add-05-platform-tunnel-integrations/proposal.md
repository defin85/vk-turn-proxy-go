# Change: [05] Add platform tunnel integrations

## Why
A universal client is not complete until it can capture and steer system traffic through platform-native tunnel mechanisms instead of only managing host sessions from a GUI shell.
That requires platform-specific tunnel integrations that should be designed only after the control plane, GUI shells, and native overlay direction are explicit.

## Sequence
- Order: `05`
- Depends on: `add-01-client-control-plane`, `add-02-desktop-gui-shell`, `add-03-mobile-gui-shell`, `add-04-native-transport-overlay`
- Unblocks: first end-to-end universal client delivery

## What Changes
- Add platform-specific tunnel integrations for desktop and mobile environments with explicit capability detection and fail-closed startup.
- Define how desktop and mobile shells request device or system traffic capture without hard-coding one OS model into the shared runtime.
- Define routing, exclusion, entitlement, and permissions boundaries needed for safe tunnel startup.

## Impact
- Affected specs: `platform-tunnel-integration`
- Affected code: future platform host modules, desktop/mobile shells, control-plane capability reporting, docs
