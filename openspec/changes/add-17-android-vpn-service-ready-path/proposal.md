# Change: [17] Add Android VPN service ready path

## Why
`add-05-platform-tunnel-integrations` currently defines only a typed host contract and fail-closed defaults for platform tunnels.
`add-14-android-embedded-mobile-host` packages a real Android host, but it explicitly stops short of `VpnService` and device-wide capture.

The repository still lacks one concrete platform tunnel mode that can reach `ready=true`.
Android is the smallest viable first target because the packaged mobile host, bridge, and release workflow already exist there.

## Sequence
- Order: `17`
- Depends on: `add-05-platform-tunnel-integrations`, `add-14-android-embedded-mobile-host`, `add-22-runtime-execution-planning`, `add-23-turn-datagram-wireguard-carrier`, `add-26-android-vpnservice-host-boundary`
- Unblocks: first concrete platform tunnel support claim, later iOS and desktop ready-path changes

## What Changes
- Define the first real platform tunnel ready path for packaged Android hosts through `android_vpn_service`.
- Define when an Android packaged host may report `android_vpn_service` as supported, which startup stages map to permission acquisition, route validation, host bring-up, and runtime attach, and what cleanup is required on failure.
- Define the Android-specific route exclusion, DNS bypass, control-traffic boundaries, and application-routing policy required so provider challenges, control-plane traffic, required underlay flows, and selected app scope do not deadlock or silently widen the tunnel bootstrap.
- Define supported Android application-routing policies for the first packaged path as explicit host-owned startup modes such as `all_apps`, `allowed_packages`, or `disallowed_packages`, with fail-closed validation for invalid or mixed package policy and reconnect-required semantics for later scope changes.
- Define how the mobile GUI shell offers the Android system tunnel workflow only when the packaged host reports the typed mode as available, including explicit app-scope selection instead of implicit full-device routing, while preserving fail-closed behavior for unsupported or mispackaged builds.
- Keep the Android `VpnService` path honest about its platform-visible VPN surface instead of claiming stealth or non-detectability from Android diagnostics.
- Add verification expectations for packaged Android smoke, denial cases, and typed ready/failure evidence for the first supported platform tunnel mode.

## Impact
- Affected specs: `platform-tunnel-integration`, `mobile-gui-client`, `android-embedded-mobile-host`, `client-control-plane`
- Affected code: future Android `VpnService` host/service wiring, app-routing policy validation and `VpnService.Builder` package allow/deny wiring, mobile bridge and shell, control-plane startup reporting, Android packaging and smoke coverage, runtime docs
