## 1. Boundary specification
- [x] 1.1 Add the new `android-vpnservice-host-boundary` capability spec for the packaged ownership split across Flutter UI, Kotlin `VpnService`, and the embedded Go host
- [x] 1.2 Extend `android-embedded-mobile-host`, `mobile-gui-client`, `client-control-plane`, and `platform-tunnel-integration` so the first Android VPN rollout uses that boundary explicitly

## 2. Delivery model
- [x] 2.1 Define the package-internal bridge responsibilities between the Go embedded host and the Kotlin `VpnService` adapter
- [x] 2.2 Define which Android VPN lifecycle responsibilities remain Kotlin-owned and which startup/runtime responsibilities remain Go-owned
- [x] 2.3 Define the ready/failure bar so `ready=true` requires both Android host bring-up and Go runtime attach
- [x] 2.4 Keep the shared boundary stage-oriented and ownership-oriented so a later `apple_network_extension` implementation can reuse the same pattern without Android API names leaking into Flutter or Go contracts

## 3. Validation
- [x] 3.1 Run `openspec validate add-26-android-vpnservice-host-boundary --strict --no-interactive`
