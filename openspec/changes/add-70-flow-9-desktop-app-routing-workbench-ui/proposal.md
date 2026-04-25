# Change: [70] Add desktop app-routing workbench UI

## Why
Once desktop app routing has a contract and a Windows host path, the desktop
shell needs a UI that lets operators choose applications without mixing that
workflow into IP routing fields.

The UI must also be honest while the host is not ready: current desktop builds
may expose `windows_wintun` status, but that does not mean they can route by
application. The workbench should show app routing as unavailable or
prerequisite-blocked until the host advertises the new capability.

## Sequence
- Flow: `9` desktop application routing
- Order: `70`
- Depends on: `add-68-flow-9-desktop-app-routing-contract`,
  `add-69-flow-9-windows-app-routing-classifier-host`,
  `add-30-flow-1-desktop-core-vpn-workbench-shell`,
  `refactor-67-flow-1-desktop-core-shared-routing-content-surface`
- Unblocks: product-grade desktop app-routing selection once a host advertises
  support

## What Changes
- Add a desktop Routing workbench surface for application routing that is
  visually and semantically separate from IP address and advanced runtime
  fields.
- Render host-provided desktop app inventory with explicit identity and
  enforceability state.
- Show unavailable and blocked states when the connected host cannot enforce
  app routing, even if a platform tunnel adapter is otherwise available.
- Persist selected app-routing selectors as profile intent, while requiring a
  reconnect/new startup attempt before implying a running tunnel changed scope.
- Keep mobile Android package selection UI unchanged.

## Impact
- Affected specs: `desktop-gui-client`, `desktop-application-routing`
- Affected code: future desktop Routing workbench UI in
  `desktop/gui_shell`, shared routing surfaces in `packages/flutter_shell_core`,
  shell persistence, i18n copy, and desktop widget tests

## Assumptions
- The desktop UI consumes host inventory and capability metadata; it does not
  scan local processes or build app identities itself.
- Saved app-routing selectors can become stale and must be validated by the
  host before startup.
