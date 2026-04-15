## 1. Android platform tunnel contract
- [x] 1.1 Define the Android-specific `android_vpn_service` capability and startup semantics, including how permission, route validation, host bring-up, runtime attach, startup-time `application_routing_policy`, and resumable `start -> permission required -> resume` flow are surfaced through the existing typed control-plane contract
- [x] 1.2 Define the fail-closed cleanup guarantees for partial Android VPN startup after permission grant, route preparation, package-policy application, or runtime attach failures

## 2. Android packaged host integration
- [x] 2.1 Implement the packaged Android host and `VpnService` lifecycle wiring needed to establish one documented `android_vpn_service` ready path
- [x] 2.2 Keep route preparation, packet capture, Android-specific DNS or exclusion behavior, and `VpnService.Builder` app allow/deny wiring inside the Android host boundary instead of leaking that logic into provider or transport packages
- [x] 2.3 Update the mobile bridge and mobile GUI shell to surface the typed Android ready and failure states plus explicit app-scope selection, including reconnect-required semantics for later scope changes and resume after Android permission grant, without inferring support from platform heuristics
- [x] 2.4 Keep the shipped Android `VpnService` mode honest about its platform-visible VPN surface instead of presenting it as a stealth path

## 3. Verification
- [x] 3.1 Add a repo-owned packaged Android smoke that proves the documented `android_vpn_service` path can return `ready=true` on the supported target
- [x] 3.2 Add fail-closed coverage for denied VPN permission, invalid route exclusion or DNS bypass policy, invalid package allow/deny policy, and runtime-attach failure cleanup
- [x] 3.3 Update runtime and operator docs so they claim only the verified Android platform tunnel mode, its supported app-routing policies, and the required evidence for support
- [x] 3.4 Run `openspec validate add-17-android-vpn-service-ready-path --strict --no-interactive`
