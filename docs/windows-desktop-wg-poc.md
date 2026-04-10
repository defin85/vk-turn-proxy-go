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
- starts `gui_shell.exe`

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

## Failure triage

- Desktop profile fails in `provider_resolve` with `vk_calls_get_anonymous_token`
  The GUI profile still uses provider `vk`. Recreate it with
  `Provider = generic-turn`.
- `WireGuard` immediately kills desktop internet
  The imported profile is wrong. Re-import the profile with
  `AllowedIPs = 0.0.0.0/1, 128.0.0.0/1` and keep the persistent host route to
  the current TURN host from the `generic-turn://...` link.
- `gui_shell.exe` starts but nothing listens on `127.0.0.1:7777`
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
