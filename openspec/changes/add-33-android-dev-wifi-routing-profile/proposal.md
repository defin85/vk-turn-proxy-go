# Change: [33] Add Android development Wi-Fi routing profile

## Why
The current Android `android_vpn_service` path can break the active local
network path that development tooling uses to reach the device over Wi-Fi.
That blocks practical live debugging workflows such as Dart MCP/DTD, wireless
`adb`, and other local development bridge traffic once the in-app VPN starts.

The repository already keeps app-routing and route-exclusion concerns explicit.
This needs to remain an honest `android_vpn_service` system-tunnel mode, but it
also needs one explicit development-oriented routing profile that preserves the
active local underlay network instead of relying on partial hidden heuristics.

## Sequence
- Order: `33`
- Depends on: `add-17-android-vpn-service-ready-path`, `add-25-android-execution-mode-separation`, `add-29-mobile-vpn-product-shell`
- Unblocks: reliable Android Wi-Fi debugging while the packaged VPN path is active, plus future local-network-aware mobile validation workflows

## What Changes
- Add a typed platform-tunnel underlay-route policy surface so hosts can
  advertise and accept an explicit development-oriented local-network bypass
  profile instead of overloading package-routing semantics.
- Define an Android `android_vpn_service` routing profile that preserves the
  active local underlay network for development/control traffic while keeping
  the mode itself an honest Android system tunnel.
- Extend the mobile `Routing` workflow so operators can choose between the
  normal routing profile and a development Wi-Fi profile with explicit copy,
  scope, and restart expectations.
- Require the Android embedded host to compute, validate, and apply active
  underlay route exclusions fail-closed, with diagnostics that show whether the
  requested profile was applied.

## Impact
- Affected specs: `client-control-plane`, `platform-tunnel-integration`, `mobile-gui-client`, `android-embedded-mobile-host`
- Affected code: `pkg/clientcontrol`, `packages/flutter_shell_core`, `mobile/gui_shell`, `internal/androidembeddedhost`, `internal/androidplatformbridge`, Android `VpnService` bridge code, and related tests/docs
