# Change: [17] Add Android VPN service ready path

## Why
`add-05-platform-tunnel-integrations` currently defines only a typed host contract and fail-closed defaults for platform tunnels.
`add-14-android-embedded-mobile-host` packages a real Android host, but it explicitly stops short of `VpnService` and device-wide capture.

The repository still lacks one concrete platform tunnel mode that can reach `ready=true`.
Android is the smallest viable first target because the packaged mobile host, bridge, and release workflow already exist there.

## Sequence
- Order: `17`
- Depends on: `add-05-platform-tunnel-integrations`, `add-14-android-embedded-mobile-host`
- Unblocks: first concrete platform tunnel support claim, later iOS and desktop ready-path changes

## What Changes
- Define the first real platform tunnel ready path for packaged Android hosts through `android_vpn_service`.
- Define when an Android packaged host may report `android_vpn_service` as supported, which startup stages map to permission acquisition, route validation, host bring-up, and runtime attach, and what cleanup is required on failure.
- Define the Android-specific route exclusion, DNS bypass, and control-traffic boundaries required so provider challenges, control-plane traffic, and required underlay flows do not deadlock the tunnel bootstrap.
- Define how the mobile GUI shell offers the Android system tunnel workflow only when the packaged host reports the typed mode as available, while preserving fail-closed behavior for unsupported or mispackaged builds.
- Add verification expectations for packaged Android smoke, denial cases, and typed ready/failure evidence for the first supported platform tunnel mode.

## Impact
- Affected specs: `platform-tunnel-integration`, `mobile-gui-client`, `android-embedded-mobile-host`
- Affected code: future Android `VpnService` host/service wiring, mobile bridge and shell, control-plane startup reporting, Android packaging and smoke coverage, runtime docs
