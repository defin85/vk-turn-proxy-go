# Change: [83] Add `linux_tun` packaged host boundary

## Why
`add-18-flow-1-desktop-core-platform-tunnel-ready-paths` explicitly reserved
future Linux desktop delivery under the same desktop platform-tunnel umbrella
that now exists for `windows_wintun`, but the Linux packaged host still uses
the generic non-Windows fallback and has no documented ownership boundary for
privileged TUN, route, or cleanup work.

Before the repository can implement a real `linux_tun` ready path, it needs an
explicit packaged-host architecture for Linux that keeps Flutter unprivileged,
keeps provider and transport-profile state out of root code, and does not
overclaim support from one ad hoc local setup.

## Sequence
- Order: `83`
- Flow: `10`
- Depends on: `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`,
  `add-28-flow-1-desktop-core-platform-tunnel-host-boundary`,
  `add-73-vpn-transport-profile-store`
- Unblocks: `add-84-flow-10-linux-tun-ubuntu-ready-path`,
  `add-85-flow-10-linux-tun-packaging-support-promotion`

## What Changes
- Define a dedicated packaged Linux desktop host boundary for `linux_tun`
  instead of continuing to rely on the generic non-Windows `clientcontrol.New`
  fallback.
- Define a repo-owned privileged helper for Linux native tunnel primitives so
  `clientd` and the Flutter shell can remain unprivileged in the first product
  slice.
- Keep transport-profile materialization, provider resolution, and ordinary
  control-plane state in the unprivileged Go host while allowing only an
  ephemeral execution lease plus route directives to cross into the privileged
  helper.
- Define helper startup, typed failure, and cleanup semantics so a Linux helper
  denial or crash does not create an undocumented second desktop tunnel API.
- Keep `linux_tun` support claims fail-closed in this change. This change
  defines the ownership boundary, not the ready-path or packaging promotion.

## Impact
- Affected specs: `desktop-platform-tunnel-host-boundary`,
  `desktop-sidecar-host`, `client-control-plane`
- Affected code: future `cmd/clientd` Linux host wiring,
  `internal/linuxdesktophost`, privileged helper packaging and IPC, Linux
  startup diagnostics
