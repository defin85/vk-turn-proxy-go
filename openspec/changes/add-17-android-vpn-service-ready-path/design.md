## Context

`add-05-platform-tunnel-integrations` established a typed platform tunnel contract, but every repo-owned host still fails closed with `stage=capability_check` and `missing_prerequisite=host_implementation`.
`add-14-android-embedded-mobile-host` then gave the Android app a packaged host and bridge, which makes Android the first target where a real platform tunnel path can be introduced without inventing a second runtime contract.

The first ready path should prove one concrete end-to-end mode instead of broad multi-platform ambition.
That means:

- one packaged Android target
- one documented `android_vpn_service` startup workflow
- explicit permission, route, and runtime-attach failures
- no hidden provider or transport fallbacks

## Goals

- Deliver the first real `ready=true` platform tunnel mode through Android `VpnService`
- Reuse the existing typed control-plane capability and startup result surface instead of inventing an Android-only tunnel protocol
- Keep route preparation, packet capture, and Android-specific DNS or bypass logic inside the packaged Android host boundary
- Preserve fail-closed behavior for denied permission, invalid route policy, and runtime-attach failures
- Require repo-owned smoke and failure evidence before the repository claims Android system tunnel support

## Non-Goals

- iOS Network Extension, Windows Wintun, or Linux TUN ready paths in this change
- A generic mobile platform tunnel abstraction that hides Android-specific constraints
- Mixing Android tunnel lifecycle logic into provider or transport packages
- Claiming background-lifecycle parity beyond the documented supported Android tunnel workflow

## Decisions

### Decision: Android `VpnService` is the first real platform tunnel mode

Android already has a packaged host, bridge, and release workflow in the repository.
Using that existing path minimizes new packaging unknowns and keeps the first supported mode aligned with the mobile product surface that already exists.

### Decision: Keep the ready path packaged-host-owned

The packaged Android host and `VpnService` layer must own permission handling, route preparation, DNS bypass behavior, packet capture, and teardown.
The Flutter shell remains a typed consumer of capability and startup results instead of a second tunnel orchestrator.

### Decision: Capability reporting stays typed, while startup remains stage-aware

The Android packaged host must continue reporting `android_vpn_service` through the existing typed capability contract.
Startup must still name the failing stage and prerequisite explicitly for permission denial, route policy problems, host bring-up failures, or runtime attach failures.

### Decision: Control traffic exclusions are mandatory for the first ready path

The supported Android mode must define which control-plane, provider-challenge, and underlay flows bypass the VPN path so startup and challenge continuation do not deadlock themselves.
If those exclusions or DNS bypass rules cannot be applied safely, startup must fail before claiming readiness.

### Decision: Ready state requires host bring-up and runtime attach proof

The repository must not claim Android system tunnel support merely because a `VpnService` instance starts.
The first supported ready path is only complete when the Android host has finished route validation, established the VPN interface, attached the shared runtime successfully, and can report that typed success through the existing startup contract.

## Risks / Trade-offs

- Android `VpnService` lifecycle and permission prompts can make startup sequencing more fragile than the current loopback-host path
- Route exclusion mistakes can break challenge continuation, control-plane access, or required underlay traffic
- A narrow first Android path may expose product pressure to generalize too early to iOS or desktop modes
- If the Android host boundary becomes too wide, platform-specific hacks can leak into the shared runtime contract

## Validation Plan

- Host and bridge tests for typed Android capability reporting and stage-aware startup results
- Android-specific fail-closed coverage for permission denial, invalid exclusion or DNS policy, and runtime-attach cleanup
- At least one repo-owned packaged Android smoke that proves `android_vpn_service` can return `ready=true` on the documented supported target
- Updated runtime and operator docs that describe only the verified Android mode and its evidence requirements
- `openspec validate add-17-android-vpn-service-ready-path --strict --no-interactive`
