# Change: Refactor Linux `linux_tun` privilege boundary

## Why

The promoted Ubuntu package currently starts the whole desktop `clientd` host
through `pkexec`/`sudo` so it can create TUN devices and update routes. Live
Ubuntu verification exposed that this boundary is too broad: the local control
plane, provider resolution, browser continuation, profile store access, and
desktop-environment bridging all cross into a root-owned process just to reach
`linux_tun`.

That makes normal host startup depend on interactive privilege mediation and
turns permission-prompt failures into `Local host blocked`. It also forces
browser continuation into a root/cross-user contour, which is brittle for
Chrome, snap Chromium, Xauthority, cookies, and desktop session state.

## What Changes

- Refactor packaged Linux startup so the GUI starts an unprivileged user-space
  `clientd` as the canonical local control plane.
- Move only Linux-native TUN, route, DNS, runtime attach, dataplane probe, and
  cleanup work behind a repo-owned privileged helper.
- Keep provider resolution, browser continuation, VPN transport-profile store
  ownership, execution-plan selection, and execution-lease materialization in
  the unprivileged host.
- Move packaged Linux VPN transport-profile persistence back to the operator
  user's host-owned store, with any legacy root-owned package store handled as
  a one-time migration/import concern instead of a second live source of truth.
- Make Linux permission acquisition a typed `/v1/platform-tunnels/start`
  startup stage instead of a prerequisite for starting the local host.
- Update Linux packaging so the unprivileged host launcher and privileged
  helper are staged and verified as separate artifacts.
- Preserve fail-closed semantics: helper denial or failure blocks only the
  `linux_tun` startup attempt and reports a typed result; it does not collapse
  the whole desktop shell into `Local host blocked`.

## Impact

- Affected specs: `desktop-sidecar-host`,
  `desktop-platform-tunnel-host-boundary`, `platform-tunnel-integration`,
  `desktop-gui-client`, `native-build-workflows`,
  `vpn-transport-profile-store`
- Affected code: `cmd/clientd` Linux host wiring, `internal/linuxdesktophost`,
  new Linux helper command/protocol, Ubuntu packaging scripts and polkit
  policy, desktop host supervisor tests, Linux package runbook
- Migration impact: current root-launched `/opt/relaydock/clientd`,
  env-bridge launcher behavior, and root-owned package profile store paths
  such as `/var/lib/relaydock/vpn-transport-profiles/store.json` become
  transitional. They should be removed from the normal path or kept only
  behind explicit legacy migration/diagnostic flows.
