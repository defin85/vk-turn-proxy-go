## 1. Desktop umbrella contract
- [ ] 1.1 Define the desktop-family platform tunnel contract so `windows_wintun`, `linux_tun`, and `apple_network_extension` remain explicit, mode-specific support claims instead of a generic desktop support bit
- [ ] 1.2 Define the desktop-family fail-closed and cleanup rules for capability gating, route validation, host bring-up, and runtime attach so later desktop modes inherit the same startup bar
- [ ] 1.3 Define how unsupported desktop targets remain explicitly unsupported until their packaged host implements a documented ready path

## 2. First Windows desktop ready path
- [ ] 2.1 Implement the packaged Windows desktop host and Wintun lifecycle wiring needed to establish one documented `windows_wintun` ready path
- [ ] 2.2 Keep driver handling, route preparation, DNS bypass, packet capture, and teardown inside the Windows host boundary instead of leaking that logic into provider, transport, or Flutter UI packages
- [ ] 2.3 Update the desktop GUI shell to surface typed desktop ready and failure states and offer only the documented system tunnel workflow for the packaged target and mode explicitly reported by the host

## 3. Verification and docs
- [ ] 3.1 Add a repo-owned packaged Windows smoke that proves the documented `windows_wintun` path can return `ready=true` on the supported target
- [ ] 3.2 Add fail-closed coverage for unsupported desktop targets, missing Windows driver or privilege, invalid route exclusion or DNS bypass policy, and runtime-attach failure cleanup
- [ ] 3.3 Update runtime and operator docs so they describe the desktop umbrella explicitly, claim only the verified Windows desktop mode, and no longer rely on operator-managed external WireGuard or manual route commands for the repo-owned Windows ready path
- [ ] 3.4 Run `openspec validate add-18-flow-1-desktop-core-platform-tunnel-ready-paths --strict --no-interactive`
