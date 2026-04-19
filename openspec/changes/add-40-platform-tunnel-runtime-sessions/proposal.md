# Change: [40] Publish platform-tunnel runtime through sessions

## Why
The current control-plane contract and mobile shell leave one architectural gap:
a packaged host can reach `ready=true` for a platform tunnel mode while the
ordinary `Sessions` surface remains empty.

That produces an incoherent operator view:

- Android can show an active system VPN while `Support -> Sessions` still shows
  zero runtime sessions
- `Resolution` records remain visible, but they are the wrong place to own
  stop, diagnostics, challenge, and runtime-failure semantics
- the shell can end up with a tunnel-only status path that competes with the
  ordinary runtime/session surface instead of reusing it

The repository already has the right domain split:
`resolution` for provider output, `platform tunnel` for host-owned OS bring-up,
and `session` for operator-visible runtime lifecycle.
The missing piece is an explicit contract that a runtime-backed, ready platform
tunnel must publish itself through the same typed session surface as any other
same-device runtime.

## Sequence
- Order: `40`
- Depends on:
  - `add-17-android-vpn-service-ready-path`
  - `add-22-runtime-execution-planning`
  - `add-23-turn-datagram-wireguard-carrier`
  - `add-29-mobile-vpn-product-shell`
  - `add-38-mobile-surface-taxonomy`
- Unblocks:
  - coherent mobile support and diagnostics surfaces for VPN-backed runtime
  - future desktop platform-tunnel runtime parity on the same session contract
  - one canonical place for stop, diagnostics, challenges, and runtime failure
    across transport paths

## What Changes
- Define that a supported platform tunnel startup which reaches runtime-backed
  `ready=true` MUST publish an ordinary typed session record instead of relying
  on tunnel-only status.
- Define correlation between platform tunnel startup and the resulting runtime
  session, including stable linkage back to the originating resolution and a
  ready-result session identifier for shells.
- Clarify that same-device startup from a resolved artifact still uses the same
  ordinary runtime/session surface even when the execution path is a packaged
  platform tunnel such as Android `VpnService`.
- Define mobile-shell behavior so VPN-backed runtime activity appears in the
  existing activity/support session surface rather than a second tunnel-owned
  runtime list.
- Keep permission, route-policy, and host bring-up detail in the typed platform
  tunnel startup result and diagnostics instead of treating those tunnel stages
  as a replacement for session lifecycle reporting.

## Impact
- Affected specs:
  - `client-control-plane`
  - `platform-tunnel-integration`
  - `provider-resolution-handoff`
  - `mobile-gui-client`
- Affected code:
  - `pkg/clientcontrol/types.go`
  - `pkg/clientcontrol/host.go`
  - `pkg/clientcontrol/resolution.go`
  - `pkg/clientcontrol/wireguard_turn_carrier.go`
  - `internal/androidembeddedhost/manager.go`
  - `internal/androidembeddedhost/platform_tunnel.go`
  - `mobile/gui_shell/lib/src/control/mobile_shell_controller.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`
  - Go and Flutter session/runtime coverage for control-plane, host, and mobile
    activity surfaces
