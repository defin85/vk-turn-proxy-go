# Change: [69] Add Windows app-routing classifier host path

## Why
`add-68-flow-9-desktop-app-routing-contract` defines the desktop app-routing
contract, but Windows needs a concrete host path before the desktop can route
applications instead of IP prefixes.

The existing `windows_wintun` work owns adapter and route preparation. That is
not enough for application routing because the host must classify traffic by
originating Windows app or process and enforce the selected policy before
traffic enters the tunnel path.

## Sequence
- Flow: `9` desktop application routing
- Order: `69`
- Depends on: `add-68-flow-9-desktop-app-routing-contract`,
  `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`,
  `add-28-flow-1-desktop-core-platform-tunnel-host-boundary`
- Unblocks: Windows-first implementation evidence for
  `add-70-flow-9-desktop-app-routing-workbench-ui`

## What Changes
- Define the Windows host as the first concrete desktop app-routing
  implementation target.
- Require a Windows process-to-flow classifier or equivalent enforcement layer
  before app routing can be advertised for `windows_wintun`.
- Require host-owned app inventory and selector validation for Windows
  executable or app identities.
- Require deterministic smoke evidence proving selected Windows app traffic is
  routed and non-selected traffic is not widened into the tunnel silently.
- Keep support fail-closed until the classifier, enforcement, cleanup, and
  evidence path are present.

## Impact
- Affected specs: `desktop-application-routing`,
  `platform-tunnel-integration`
- Affected code: future `internal/windowsdesktophost`, `pkg/clientcontrol`,
  Windows app inventory and classifier/enforcement adapters, desktop host
  tests, and Windows verification scripts

## Assumptions
- The production implementation may use Windows-native filtering or a
  diversion/proxy layer, but this change does not bless a specific mechanism
  before feasibility and packaging evidence exist.
- The Windows implementation remains host-owned; Flutter does not classify
  processes or install privileged filters.
