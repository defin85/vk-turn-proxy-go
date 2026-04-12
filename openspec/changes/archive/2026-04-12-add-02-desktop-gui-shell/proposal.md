# Change: [02] Add desktop GUI shell

## Why
Desktop operators currently need to manage the runtime through CLI commands and manual browser steps.
A first-party desktop GUI is the fastest way to make the canonical repository usable on Windows, macOS, and Linux without waiting for platform-specific mobile tunnel work.

## Sequence
- Order: `02`
- Depends on: `add-01-client-control-plane`
- Unblocks: `add-05-platform-tunnel-integrations`

## What Changes
- Add a desktop GUI shell that manages profiles, sessions, logs, diagnostics, and provider challenges through the local client control plane.
- Package and supervise a local sidecar host for Windows, macOS, and Linux instead of depending on direct CLI invocation from the UI.
- Use system-browser-oriented challenge handoff and explicit desktop capability reporting.

## Impact
- Affected specs: `desktop-gui-client`
- Affected code: future desktop app workspace, future `cmd/clientd`, packaging/distribution assets, control-plane integration, docs
