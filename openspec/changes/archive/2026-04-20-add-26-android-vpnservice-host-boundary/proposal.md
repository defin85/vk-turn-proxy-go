# Change: [26] Add Android `VpnService` host boundary

## Why
`add-17-android-vpn-service-ready-path` already defines the first honest
Android system-tunnel path, but it does not yet pin down the packaged-host
ownership split between Flutter UI, the Android native layer, and the embedded
Go host.

The repository now has all three pieces in flight:

- a Flutter mobile shell
- a packaged Go embedded host
- an Android-native app layer

Without an explicit boundary, implementation pressure will drift in the wrong
direction:

- Flutter may start owning VPN lifecycle heuristics
- Go may try to own Android OS primitives directly
- Kotlin may become a second control plane instead of an adapter boundary

The first Android `VpnService` rollout needs one authoritative delivery model:
Flutter UI, Kotlin `VpnService`, Go control-plane/runtime.
That model should also stay iOS-friendly at the boundary level so a future
`apple_network_extension` path can reuse the same ownership split without
pretending that Android and iOS share one native lifecycle.

## Sequence
- Order: `26`
- Depends on: `add-14-android-embedded-mobile-host`, `add-22-runtime-execution-planning`, `add-23-turn-datagram-wireguard-carrier`
- Unblocks: implementation of `add-17-android-vpn-service-ready-path` on a repo-owned packaged boundary

## What Changes
- Add a new `android-vpnservice-host-boundary` capability spec that fixes the
  packaged Android ownership split for the first repo-owned system-tunnel path.
- Define Flutter as the typed UI consumer only: it renders capability, app-scope,
  startup, and failure state, but does not own `VpnService` lifecycle or packet
  capture.
- Define Kotlin/Android as the OS adapter boundary: it owns permission prompts,
  `VpnService`, `VpnService.Builder`, foreground-service requirements, package
  allow/deny policy application, and Android-specific teardown.
- Define the embedded Go host as the canonical control-plane/runtime owner: it
  owns typed `/v1/platform-tunnels/start`, consumes the already-documented
  runtime-execution and carrier prerequisites through the canonical host
  contract, and remains the authoritative source of stage-aware ready/failure
  state.
- Require a package-internal bridge between the Go embedded host and the Kotlin
  `VpnService` adapter instead of a second Flutter- or Android-only tunnel API.
- Keep that boundary Android-first but reusable at the ownership level so a
  future `apple_network_extension` path can fit the same Flutter/native-adapter/Go
  split without leaking Android API names into shared shell or control-plane
  contracts, while still allowing the future native adapter to use a different
  process or extension lifecycle from Android `VpnService`.
- Extend Android embedded-host, mobile GUI, client-control-plane, and
  platform-tunnel specs so the first Android VPN path uses that boundary
  explicitly.

## Impact
- Affected specs: `android-vpnservice-host-boundary` (new), `android-embedded-mobile-host`, `mobile-gui-client`, `client-control-plane`, `platform-tunnel-integration`
- Affected code: future Android native bridge/service wiring, embedded-host startup orchestration, mobile shell system-tunnel UX, and Android packaging/smoke workflows
