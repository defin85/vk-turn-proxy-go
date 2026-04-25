# Change: [28] Add desktop platform-tunnel host boundary

## Why
`add-18-flow-1-desktop-core-platform-tunnel-ready-paths` already defines the desktop
umbrella and the first concrete `windows_wintun` delivery slice, but it does
not yet pin down the reusable ownership boundary between the desktop Flutter
shell, the packaged desktop host/sidecar, and the OS-specific tunnel adapter.

That gap is the desktop equivalent of the earlier Android boundary problem:

- the desktop GUI could drift into shell-local tunnel orchestration
- one OS-specific helper could grow into an implicit second control plane
- later Linux or Apple desktop work could reopen the ownership question from
  scratch instead of reusing one repo-owned model

Desktop needs one explicit host-boundary change so the first Windows rollout is
implemented on a reusable architecture rather than as a Windows-only special
case.

## Sequence
- Order: `28`
- Depends on: `add-02-desktop-gui-shell`, `add-18-flow-1-desktop-core-platform-tunnel-ready-paths`, `add-22-runtime-execution-planning`, `add-23-turn-datagram-wireguard-carrier`
- Unblocks: concrete implementation of `add-18` and later `linux_tun` / desktop `apple_network_extension` follow-on changes on a shared ownership model

## What Changes
- Add a new `desktop-platform-tunnel-host-boundary` capability spec that fixes
  the packaged ownership split for repo-owned desktop system-tunnel paths.
- Define the desktop Flutter shell as the typed UI consumer only: it renders
  capability, execution-plan choice, and stage-aware startup state, but does
  not own OS tunnel primitives, route manipulation, or driver/extension
  lifecycle.
- Define the packaged desktop host/sidecar as the native adapter boundary for
  supported desktop modes: it owns driver or extension acquisition, route and
  DNS policy application, OS packet-capture lifecycle, and cleanup.
- Define the Go control plane as the canonical orchestrator: it owns typed
  `/v1/platform-tunnels/start`, runtime-execution planning, strict
  TURN-datagram carrier materialization, and ready/failure reporting.
- Require cross-boundary desktop startup to stay stage-oriented and
  ownership-oriented so later `linux_tun` and desktop
  `apple_network_extension` implementations can reuse the same model without
  inheriting Windows API names.
- Extend `desktop-sidecar-host`, `desktop-gui-client`,
  `client-control-plane`, and `platform-tunnel-integration` so the desktop
  umbrella uses that boundary explicitly.

## Impact
- Affected specs: `desktop-platform-tunnel-host-boundary` (new), `desktop-sidecar-host`, `desktop-gui-client`, `client-control-plane`, `platform-tunnel-integration`
- Affected code: future Windows/Linux/macOS desktop host boundary wiring, desktop sidecar/native helper IPC, desktop GUI system-tunnel UX, and packaged desktop verification workflows
