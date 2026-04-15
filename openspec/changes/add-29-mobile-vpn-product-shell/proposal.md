# Change: [29] Add mobile VPN product shell

## Why
`add-17-android-vpn-service-ready-path` delivered a real Android `VpnService`
path, but the current mobile shell is still shaped like a diagnostics-first
operator surface.

That mismatch is now product debt. Comparable VPN and proxy apps typically put
the connection state, selected profile, and one dominant connect or disconnect
action on the primary mobile surface, while profiles, per-app routing, logs,
and diagnostics live behind dedicated secondary destinations.

## Sequence
- Order: `29`
- Depends on: `add-17-android-vpn-service-ready-path`, `add-25-android-execution-mode-separation`
- Unblocks: a product-grade Android mobile shell that uses the delivered VPN
  path without forcing ordinary operators through a diagnostics-heavy workflow

## What Changes
- Refine `mobile-gui-client` so the primary phone-sized shell becomes a
  VPN-first product surface instead of a stacked diagnostics/workflow editor.
- Require a dedicated mobile home that centers the current profile, runtime
  mode, scope summary, and one dominant start or disconnect control.
- Require profile management and per-app routing to move into their own
  dedicated destinations instead of remaining inline with the home workflow.
- Keep activity, logs, and diagnostics explicit but secondary, with drill-down
  access from the home surface rather than default first-screen prominence.
- Require the shell to describe `android_vpn_service` honestly as a system VPN
  mode and to keep future non-system modes visually and semantically distinct.

## Impact
- Affected specs: `mobile-gui-client`
- Affected code: `mobile/gui_shell/lib/src/ui/dashboard_page.dart`,
  `mobile/gui_shell/lib/src/ui/profile_editor.dart`,
  `mobile/gui_shell/lib/src/control/mobile_shell_controller.dart`, and the
  mobile navigation and routing surfaces that currently keep profile editing,
  activity, and diagnostics too close together
