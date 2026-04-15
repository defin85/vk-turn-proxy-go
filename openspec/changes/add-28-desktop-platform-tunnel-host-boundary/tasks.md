## 1. Boundary specification
- [ ] 1.1 Add the new `desktop-platform-tunnel-host-boundary` capability spec for the packaged ownership split across the desktop Flutter shell, the packaged desktop host, and the Go control plane
- [ ] 1.2 Extend `desktop-sidecar-host`, `desktop-gui-client`, `client-control-plane`, and `platform-tunnel-integration` so the desktop umbrella uses that boundary explicitly

## 2. Delivery model
- [ ] 2.1 Define which desktop tunnel lifecycle responsibilities remain packaged-host-owned and which startup/runtime responsibilities remain Go-owned
- [ ] 2.2 Keep the shared desktop boundary stage-oriented and ownership-oriented so later `linux_tun` and desktop `apple_network_extension` implementations can reuse the same pattern without Windows API names leaking into Flutter or Go contracts
- [ ] 2.3 Define the ready/failure bar so `ready=true` requires both native desktop adapter bring-up and Go runtime attach

## 3. Validation
- [ ] 3.1 Run `openspec validate add-28-desktop-platform-tunnel-host-boundary --strict --no-interactive`
