# Change: [01] Add client control plane

## Why
The repository currently exposes CLI entrypoints and structured logs, but a universal GUI client cannot safely depend on parsing flags, stdout, or stderr.
A stable local control plane is needed before desktop and mobile shells can manage sessions, challenges, diagnostics, and version compatibility.

## Sequence
- Order: `01`
- Depends on: none
- Unblocks: `add-02-desktop-gui-shell`, `add-03-mobile-gui-shell`, `add-05-platform-tunnel-integrations`

## What Changes
- Introduce a versioned local client control plane for profiles, session lifecycle, challenge handoff, event streaming, and diagnostics export.
- Add a dedicated daemon-style host process for desktop use plus an embeddable host facade for mobile platforms.
- Keep existing CLI entrypoints available while making them consumers of the same control-plane-aware runtime primitives.

## Impact
- Affected specs: `client-control-plane`
- Affected code: future `cmd/clientd`, `cmd/tunnel-client`, `internal/session`, `internal/providerprompt`, `internal/observe`, future client API packages
