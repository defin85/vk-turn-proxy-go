# Change: [68] Add desktop application-routing contract

## Why
The current application-routing contract is Android package routing:
`android_vpn_service` can scope the VPN to selected packages, while desktop
`windows_wintun` rejects `application_routing_policy` inputs today.

Desktop app routing needs a separate contract before implementation work starts.
It is closer to a Proxyfier-style per-application routing model than to IP route
selection, so the repository must define desktop application identities,
capability negotiation, and fail-closed startup semantics without pretending
that existing Wintun route support already provides app-level selection.

## Sequence
- Flow: `9` desktop application routing
- Order: `68`
- Depends on: `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`,
  `add-28-flow-1-desktop-core-platform-tunnel-host-boundary`,
  `add-30-flow-1-desktop-core-vpn-workbench-shell`
- Unblocks: `add-69-flow-9-windows-app-routing-classifier-host`,
  `add-70-flow-9-desktop-app-routing-workbench-ui`

## What Changes
- Add a new `desktop-application-routing` capability for desktop
  app-identity-based route selection.
- Define desktop app routing as a host-enforced selector policy over
  host-reported desktop application identities, not Android package names and
  not destination IP rules.
- Extend `client-control-plane` so shells can negotiate desktop app-routing
  support and submit typed desktop app selectors only when a host advertises an
  enforcement-capable mode.
- Extend `platform-tunnel-integration` so platform-tunnel support claims do not
  imply app-routing support unless a host advertises and verifies a classifier
  or enforcement layer for that mode.
- Keep existing Android `application_routing_policy` semantics unchanged.

## Impact
- Affected specs: `desktop-application-routing` (new),
  `client-control-plane`, `platform-tunnel-integration`
- Affected code: future `pkg/clientcontrol` capability/startup schema,
  desktop platform-tunnel hosts, desktop shell routing UI, and app-routing
  verification fixtures

## Assumptions
- The first desktop implementation target is Windows, but the base contract
  must not bake Windows-only identifiers into the cross-platform desktop API.
- Existing IP route and Wintun readiness work remains useful, but app routing
  needs an additional process/application classification layer.
