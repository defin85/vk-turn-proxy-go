# Windows Desktop windows_wintun Ready Path

This document captures the verified repo-owned Windows desktop `windows_wintun`
workflow.
It is the packaged-host proof path for add-18, not the older external
`WireGuard for Windows` compatibility flow.

Use `docs/windows-desktop-live-vk-workflow.md` when the task starts from a live
VK invite and still ends in the explicit external compatibility workflow.

## Scope

This runbook proves:

- the bundled Windows `clientd.exe` reports `windows_wintun` honestly through
  `/v1/host`
- the packaged host keeps `windows_wintun` fail-closed until its documented
  prerequisites are satisfied
- the packaged host can return `ready=true` for `windows_wintun`
- the packaged host tears the tunnel down again through the same typed control
  plane

This runbook does not claim:

- the live VK invite workflow
- Linux `linux_tun` or Apple `apple_network_extension`
- the older external `WireGuard for Windows` transport-ingress workflow

## Required inputs

- a fresh Windows desktop bundle built through
  `./scripts/build-windows-gui-from-wsl.sh`
- the mirrored Windows-native bundle at
  `E:\Projects\vk-turn-proxy-go\dist\windows-gui`
- a Windows VM or other disposable Windows execution cell when route or driver
  experiments must not touch the host machine
- one reusable `generic-turn://...` link or an already resolved reusable
  `generic-turn` source
- the local strict WireGuard materializer profile at
  `~/.local/state/vk-turn-proxy-go/wg/desktop1-windows.conf`
  or an explicit override through `VKTP_WINDOWS_WIREGUARD_PROFILE`
- elevated PowerShell for the packaged host checks and smoke

The local profile is a packaged-host prerequisite for the strict
`turn_datagram + wireguard_native + windows_wintun` path.
It is not the older external `WireGuard for Windows` client workflow.

## Safe VMware execution cell

When the operator must prove `windows_wintun` without rewriting the workstation
routes, use the VMware-backed Windows lab:

- VMware-hosted Windows 10 guest
- guest access over `ssh`
- repo-owned sync helper: `./scripts/sync-windows-vm-lab.sh`
- guest launcher: `C:\Users\codex\vk-turn-lab\scripts\run-vm-lab-shell.ps1`
- guest preflight: `C:\Users\codex\vk-turn-lab\scripts\assert-vm-lab-host.ps1`
- guest packaged-host smoke:
  `C:\Users\codex\vk-turn-lab\scripts\smoke-windows-wintun.ps1`

## Verified operator loop

1. Build the fresh Windows bundle from WSL:

```bash
./scripts/build-windows-gui-from-wsl.sh
```

2. Sync the bundle and guest helpers into the Windows VM:

```bash
./scripts/sync-windows-vm-lab.sh
```

3. Verify the bundled guest-side host surface:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\codex\vk-turn-lab\scripts\assert-vm-lab-host.ps1 -RequireWireGuardProfile
```

That preflight fails closed unless:

- bundled `RelayDock.exe`, `clientd.exe`, and `wintun.dll` are present
- the PowerShell session is elevated
- `/v1/host` answers from the bundled `clientd.exe`
- `platform_tunnels` reports `windows_wintun available=true`
- the host advertises `preserve_active_local_network`
- the documented local WireGuard materializer profile is present

4. Prove the repo-owned `windows_wintun` startup path can return `ready=true`:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\codex\vk-turn-lab\scripts\smoke-windows-wintun.ps1 -RequireWireGuardProfile
```

That smoke:

- starts the bundled `clientd.exe`
- selects the documented supported `windows_wintun` execution plan
- creates or reuses one resolved `generic-turn` source
- starts `/v1/platform-tunnels/start`
- requires `ready=true`
- requires `session_id`
- stops `/v1/platform-tunnels/stop` again before exit

If the operator does not pass `-TurnLink`, the smoke first looks for the saved
`desktop-generic-turn` profile and reuses its `generic-turn://...` link.

5. Launch the bundled guest-side GUI only after the preflight or smoke succeeds:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Users\codex\vk-turn-lab\scripts\run-vm-lab-shell.ps1
```

The guest sync and launcher stay fail-closed:

- they require bundled `RelayDock.exe`
- they require bundled `clientd.exe`
- they require bundled `wintun.dll`
- they do not fall back to legacy `gui_shell.exe`
- they stage `desktop1-windows.conf` into the guest only as packaged-host
  materializer input, not as proof of an external compatibility workflow
- the lab launcher and smoke set `VKTP_WINDOWS_WIREGUARD_PROFILE` to the staged
  profile path so the packaged host uses the same materializer input even when
  the GUI is started from a different Windows user profile

## Local WireGuard materializer profile

The validated profile for the packaged Windows host lives outside the
repository by default:

- Linux or WSL source path:
  `~/.local/state/vk-turn-proxy-go/wg/desktop1-windows.conf`
- Windows default path:
  `C:\Users\<user>\.local\state\vk-turn-proxy-go\wg\desktop1-windows.conf`

You may override that path with `VKTP_WINDOWS_WIREGUARD_PROFILE`.

The packaged host loads that file to materialize the strict WireGuard carrier
lease.
If the file is missing or invalid, `/v1/host` keeps `windows_wintun`
fail-closed and the desktop shell must not offer the repo-owned system tunnel
workflow.

## Notes

- Use the mirrored native checkout under `E:\Projects\vk-turn-proxy-go` for the
  Windows build itself, not as proof that the host machine stayed untouched.
- Keep the VM disposable when you are experimenting with drivers, routes, or
  firewall state.
- Do not treat this runbook as proof of Linux or Apple desktop support.
