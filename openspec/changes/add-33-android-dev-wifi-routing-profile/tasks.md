## 1. Contract
- [ ] 1.1 Add spec deltas for a typed platform-tunnel `underlay_route_policy` surface and explicit host capability advertisement.
- [ ] 1.2 Define fail-closed startup behavior when the requested development local-network profile is unsupported or cannot be prepared safely.

## 2. Android Host
- [ ] 2.1 Extend the Android platform-tunnel start request, bridge payload, and host validation to carry the selected underlay-route policy.
- [ ] 2.2 Implement active local underlay-network exclusion for the development profile, preferring platform-native route exclusion when available and keeping a deterministic fallback otherwise.
- [ ] 2.3 Surface effective underlay-route policy and route-preparation failures through typed diagnostics and startup results.

## 3. Mobile Shell
- [ ] 3.1 Extend the mobile `Routing` workflow to expose the standard profile and the explicit `Development Wi-Fi` profile only when the connected host advertises support.
- [ ] 3.2 Persist the selected underlay-route policy in mode preferences and require an explicit VPN restart when the operator changes it.
- [ ] 3.3 Add controller/widget coverage for supported, unsupported, and fail-closed UX states.

## 4. Validation
- [ ] 4.1 Run `openspec validate add-33-android-dev-wifi-routing-profile --strict --no-interactive`.
- [ ] 4.2 Run the smallest relevant Go and Flutter test sets for the new contract, Android host logic, and mobile shell routing UI.
- [ ] 4.3 Verify on a physical Android device that Wi-Fi-connected development tooling remains reachable while the repo-owned Android VPN is active with the development profile selected.
