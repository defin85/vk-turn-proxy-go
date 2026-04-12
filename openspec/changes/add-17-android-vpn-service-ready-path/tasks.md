## 1. Android platform tunnel contract
- [ ] 1.1 Define the Android-specific `android_vpn_service` capability and startup semantics, including how permission, route validation, host bring-up, and runtime attach are surfaced through the existing typed control-plane contract
- [ ] 1.2 Define the fail-closed cleanup guarantees for partial Android VPN startup after permission grant, route preparation, or runtime attach failures

## 2. Android packaged host integration
- [ ] 2.1 Implement the packaged Android host and `VpnService` lifecycle wiring needed to establish one documented `android_vpn_service` ready path
- [ ] 2.2 Keep route preparation, packet capture, and Android-specific DNS or exclusion behavior inside the Android host boundary instead of leaking that logic into provider or transport packages
- [ ] 2.3 Update the mobile bridge and mobile GUI shell to surface the typed Android ready and failure states without inferring support from platform heuristics

## 3. Verification
- [ ] 3.1 Add a repo-owned packaged Android smoke that proves the documented `android_vpn_service` path can return `ready=true` on the supported target
- [ ] 3.2 Add fail-closed coverage for denied VPN permission, invalid route exclusion or DNS bypass policy, and runtime-attach failure cleanup
- [ ] 3.3 Update runtime and operator docs so they claim only the verified Android platform tunnel mode and list the required evidence for support
- [ ] 3.4 Run `openspec validate add-17-android-vpn-service-ready-path --strict --no-interactive`
