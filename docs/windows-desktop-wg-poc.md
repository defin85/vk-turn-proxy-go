# Windows Desktop WireGuard PoC

This document captures the validated Windows desktop operator workflow for
routing real PC traffic through external `WireGuard for Windows` over the
current `udp -> udp` transport slice.

The desktop shell is only the local transport ingress in this path.
System VPN still belongs to the external `WireGuard` client.

## Scope

This workflow proves:

- the packaged Windows desktop shell can expose a real local transport ingress
- the bundled `clientd.exe` can keep a `generic-turn` session in `ready`
- the external `WireGuard for Windows` client can use `127.0.0.1:39010` as its
  UDP endpoint
- the VPS `WireGuard` gateway can NAT that traffic to the public internet

This workflow does not claim:

- repo-owned `windows_wintun`
- one-app desktop VPN product support
- the live VK invite workflow from `docs/windows-desktop-live-vk-workflow.md`;
  this PoC starts from an already resolved `generic-turn://...` link

## Required inputs

- a fresh Windows desktop bundle built through
  `./scripts/build-windows-gui-from-wsl.sh`
- the mirrored Windows-native bundle at
  `E:\Projects\vk-turn-proxy-go\dist\windows-gui`
- the official `WireGuard for Windows` client
- a real `generic-turn://...` link
- the VPS `wg-quick@wgvktp0.service` and `vk-turn-tunnel-wg.service` already
  running

## Safe VMware execution cell

When the operator must prove the Windows desktop transport path without
changing the host machine routes, run this PoC inside a Windows VM and keep the
Linux or WSL checkout only as the build machine.

Validated contour on this workstation:

- VMware-hosted Windows 10 guest
- guest networking kept inside the VM; desktop VPN enable or disable does not
  rewrite the Linux or Windows host routes
- guest access over `ssh` with key auth
- elevated PowerShell available inside the guest for the repo-owned
  `windows_wintun` path
- artifact sync through `scp -O`, because this Windows OpenSSH setup may reject
  the modern `scp` or `sftp` subsystem path
- repo-owned guest sync helper:
  `./scripts/sync-windows-vm-lab.sh`
- repo-owned guest launcher:
  `C:\Users\codex\vk-turn-lab\scripts\run-vm-lab-shell.ps1`
- repo-owned guest host smoke:
  `C:\Users\codex\vk-turn-lab\scripts\assert-vm-lab-host.ps1`

The verified operator loop is:

1. build the fresh Windows bundle from WSL:

```bash
./scripts/build-windows-gui-from-wsl.sh
```

2. sync the packaged bundle and Windows helpers into the guest:

```bash
./scripts/sync-windows-vm-lab.sh
```

3. verify the bundled guest-side host surface before launching the GUI:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\codex\vk-turn-lab\scripts\assert-vm-lab-host.ps1 -RequireWireGuardProfile
```

That smoke fails closed unless:

- bundled `RelayDock.exe`, `clientd.exe`, and `wintun.dll` are all present
- the PowerShell session is elevated
- `/v1/host` answers from the bundled `clientd.exe`
- `platform_tunnels` reports `windows_wintun available=true`
- the host advertises `preserve_active_local_network`
- the validated guest-side `desktop1-windows.conf` profile is present when
  `-RequireWireGuardProfile` is used

4. prove the repo-owned `windows_wintun` startup path can return `ready=true`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\codex\vk-turn-lab\scripts\smoke-windows-wintun.ps1 -RequireWireGuardProfile
```

That smoke starts the bundled `clientd.exe`, selects the documented supported
`windows_wintun` execution plan, creates or reuses one resolved
`generic-turn` source, starts `/v1/platform-tunnels/start`, requires
`ready=true`, then stops the platform tunnel again.

If the operator does not pass `-TurnLink`, the smoke first looks for the saved
`desktop-generic-turn` profile and reuses its `generic-turn://...` link.

5. start the bundled guest-side sidecar and GUI inside the VM:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\codex\vk-turn-lab\scripts\run-vm-lab-shell.ps1
```

The guest sync and launcher are fail-closed:

- it requires bundled `RelayDock.exe`
- it requires bundled `clientd.exe`
- it requires bundled `wintun.dll`
- it does not fall back to legacy `gui_shell.exe`
- the sync helper clears the old guest bundle before extraction so stale files
  do not survive rebuilds
- when `~/.local/state/vk-turn-proxy-go/wg/desktop1-windows.conf` exists on the
  Linux or WSL build machine, the sync helper also stages it into the guest at
  `C:\Users\codex\.local\state\vk-turn-proxy-go\wg\desktop1-windows.conf`

Use this VM contour when you need a safe desktop VPN lab. Use the mirrored
native checkout under `E:\Projects\vk-turn-proxy-go` only for the Windows build
itself, not as proof that the host machine stayed untouched.

If you expect route or firewall experiments to drift over time, keep this VM as
disposable state: use a clone, a cold backup of the VM directory, or an
explicit VMware snapshot policy before risky runs.

## One-time route exclusion

The transport app must reach the TURN server outside the desktop VPN.
Add a persistent host route for the TURN IP from the current
`generic-turn://...` link through the normal LAN gateway.
The validated run on this machine used `155.212.205.169`.

Resolve the current default gateway:

```powershell
$gw = (Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1).NextHop
```

Set the current TURN IP, then add the route:

```powershell
$turnHost = '155.212.205.169'
route -p add $turnHost mask 255.255.255.255 $gw metric 1
```

Confirm it exists:

```powershell
route print $turnHost
```

## One-time WireGuard profile

The validated profile for the first Windows desktop lives outside the repository
in:

- `~/.local/state/vk-turn-proxy-go/wg/desktop1-windows.conf`

On Windows, that same file is:

- `C:\Users\<user>\.local\state\vk-turn-proxy-go\wg\desktop1-windows.conf`

The VM sync helper copies that file into the guest automatically when the Linux
or WSL source file exists at sync time. If the source machine keeps it in a
different location, point `scripts/sync-windows-vm-lab.sh` at it with
`LOCAL_WIREGUARD_PROFILE=/custom/path/desktop1-windows.conf`.

The critical `AllowedIPs` line is:

```ini
AllowedIPs = 0.0.0.0/1, 128.0.0.0/1
```

Do not change that to `0.0.0.0/0` for this PoC.
With `/0`, `WireGuard for Windows` enables its built-in kill-switch behavior
and can break `clientd -> TURN` even when the host route above already exists.

## Repo-owned sidecar launch helper

Start the bundled desktop sidecar and GUI from the mirrored Windows-native
bundle:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\run-windows-gui-shell.ps1
```

The helper:

- requires Windows-native paths, not `\\wsl.localhost\...`
- stops any existing `clientd.exe` that already owns `127.0.0.1:7777`
- starts the bundled `clientd.exe`
- waits until `/v1/host` is reachable
- starts `RelayDock.exe`
- waits for `RelayDock.exe` to exit and then stops the owned `clientd.exe`

Use the companion session helper to upsert and start the packaged
`generic-turn` desktop profile without manual form editing:

```powershell
$env:TURN_LINK = 'generic-turn://...'
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-desktop-generic-turn.ps1 start -ReplaceExisting
```

If the bundled files are locked during rebuild, close any running desktop shell
and `clientd.exe` first, then rebuild again.

## Reproducible run

1. Build or rebuild the Windows desktop bundle:

```bash
./scripts/build-windows-gui-from-wsl.sh
```

2. Keep `WireGuard for Windows` disabled.
3. Start the fresh bundled sidecar and GUI:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\run-windows-gui-shell.ps1
```

4. Start the repo-owned desktop session helper:

```powershell
$env:TURN_LINK = 'generic-turn://...'
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-desktop-generic-turn.ps1 start -ReplaceExisting
```

5. Confirm the helper reports `ready`.
6. Import `desktop1-windows.conf` into `WireGuard for Windows`.
7. Verify that `AllowedIPs` remains `0.0.0.0/1, 128.0.0.0/1`.
8. Enable the imported `WireGuard` tunnel.
9. Open any public IP check page in the browser.

## Optional: Capture offline WireGuard failure evidence

When enabling `WireGuard for Windows` may cut operator connectivity, start the
repo-owned health capture helper first and then enable the tunnel while it is
sampling:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-wireguard-health-capture.ps1 -DurationSeconds 120 -SampleIntervalSeconds 2 -OutputDir E:\Projects\vk-turn-proxy-go\artifacts\windows-wireguard-health\latest
```

The helper captures:

- `clientd` host, sessions, and per-session diagnostics when available
- `WireGuard` service state and `wg.exe show`
- Wintun adapter state, IPv4 interfaces, default routes, split routes, and public `/32` host routes
- connectivity probes to the current LAN gateway, the desktop session peer host, one external IP, and one DNS lookup
- raw `route print` and `ipconfig /all` snapshots at the start and end of the run

Use a fixed `-OutputDir` such as `...\latest` when you want the evidence path to
stay predictable across retries.

## Failure triage

- Desktop profile fails in `provider_resolve` with `vk_calls_get_anonymous_token`
  The GUI profile still uses provider `vk`. Recreate it with
  `Provider = generic-turn`.
- `WireGuard` immediately kills desktop internet
  The imported profile is wrong. Re-import the profile with
  `AllowedIPs = 0.0.0.0/1, 128.0.0.0/1` and keep the persistent host route to
  the current TURN host from the `generic-turn://...` link.
- `RelayDock.exe` starts but nothing listens on `127.0.0.1:7777`
  Start the bundle through `scripts/run-windows-gui-shell.ps1` instead of
  launching the GUI by hand.
- Session helper fails before `ready`
  Export diagnostics with
  `scripts/windows-desktop-generic-turn.ps1 diagnostics` and inspect the
  latest session failure stage instead of guessing from the GUI alone.
- Windows bundle in `dist/windows-gui/` stays stale after rebuild
  A running `clientd.exe` or GUI still holds files open during the copy-back
  step. Close the desktop processes, rebuild again, or use the mirrored bundle
  in `E:\Projects\vk-turn-proxy-go\dist\windows-gui`.
- Session reaches `ready` and then dies with `read relay datagram: EOF`
  Rebuild the Windows artifacts and rerun the helper. This was observed with
  stale Windows binaries before the fresh 2026-04-09 rebuild.
