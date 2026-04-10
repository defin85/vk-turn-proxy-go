# Windows Desktop Live VK Workflow

This document defines the repo-owned desktop workflow for exercising the
packaged Windows desktop shell with a real VK invite without claiming direct
live VK resolution inside the GUI itself.

The workflow keeps the current boundary explicit:

1. resolve the live VK invite on WSL through `cmd/probe`
2. reuse the derived short-lived `generic-turn://...` link on Windows
3. run the packaged desktop shell over the existing external `WireGuard`
   desktop path

## Scope

This workflow proves:

- a real VK invite can be resolved on WSL into a short-lived
  `generic-turn://...` link through the repo-owned probe path
- the packaged Windows desktop host can start a `generic-turn` session from
  that derived link
- the external `WireGuard for Windows` client can still use the desktop shell
  as local transport ingress after the live preflight step

This workflow does not claim:

- direct VK browser continuation inside the Flutter desktop UI
- repo-owned system VPN or `wintun` integration
- unattended live VK resolution on Windows

## Required inputs

- a real VK invite URL
- local browser support on WSL for the controlled VK continuation browser
- a fresh Windows desktop bundle built through
  `./scripts/build-windows-gui-from-wsl.sh`
- the mirrored Windows-native bundle at
  `E:\Projects\vk-turn-proxy-go\dist\windows-gui`
- the official `WireGuard for Windows` client
- the validated `desktop1-windows.conf` profile from
  `docs/windows-desktop-wg-poc.md`
- the VPS `wg-quick@wgvktp0.service` and `vk-turn-tunnel-wg.service` already
  running

## Step 1: Resolve the live VK invite on WSL

Run the live probe from the canonical WSL checkout:

```bash
cd /home/egor/code/vk-turn-proxy-go
VK_PROVIDER_BROWSER_HEADLESS=false \
go run ./cmd/probe \
  -provider vk \
  -link 'https://vk.com/call/join/<invite>' \
  -interactive-provider \
  -emit-generic-turn-link \
  -output-dir ./artifacts/windows-desktop-live-vk
```

After the human completes the browser challenge, `probe` prints:

```text
generic_turn_link=generic-turn://...
```

Use that exact value as `TURN_LINK` for the Windows desktop helper below.

## Step 2: Resolve the TURN host for the Windows route exclusion

Export the printed link in WSL and extract the host:

```bash
TURN_LINK='generic-turn://...'
python3 -c "import os, urllib.parse; print(urllib.parse.urlparse(os.environ['TURN_LINK']).hostname)"
```

Keep both values:

- the full `TURN_LINK`
- the extracted TURN host/IP

## Step 3: Add the Windows host route for that TURN host

Resolve the current default gateway:

```powershell
$gw = (Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1).NextHop
```

Set the actual TURN host extracted above, then add the persistent route:

```powershell
$turnHost = '155.212.205.169'
route -p add $turnHost mask 255.255.255.255 $gw metric 1
route print $turnHost
```

This route must target the real host from the live-derived `TURN_LINK`, not a
stale host from an older run.

## Step 4: Start the bundled desktop shell

Launch the repo-owned Windows helper from the mirrored checkout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\run-windows-gui-shell.ps1
```

That starts a fresh bundled `clientd.exe`, waits for `/v1/host`, and then
launches `gui_shell.exe`.

## Step 5: Start the Windows desktop transport session

Pass the live-derived `TURN_LINK` into the Windows helper and start the saved
`generic-turn` profile:

```powershell
$env:TURN_LINK = 'generic-turn://...'
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-desktop-generic-turn.ps1 start -ReplaceExisting
```

The helper:

- talks to the bundled `clientd` over `http://127.0.0.1:7777`
- upserts a stable `desktop-generic-turn` profile
- uses `127.0.0.1:39010` as the local UDP ingress
- uses `176.109.104.105:56040` as the VPS peer
- waits until the desktop session reaches `ready`

You can inspect the current state later with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-desktop-generic-turn.ps1 status
```

And export diagnostics with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-desktop-generic-turn.ps1 diagnostics
```

## Step 6: Enable the external WireGuard tunnel

Once the desktop transport session is `ready`:

1. import `desktop1-windows.conf` into `WireGuard for Windows` if needed
2. confirm `AllowedIPs` still stays `0.0.0.0/1, 128.0.0.0/1`
3. enable the imported tunnel
4. open any public IP check page in the browser

The `WireGuard` profile itself still follows the validated contract in
`docs/windows-desktop-wg-poc.md`.

## Failure triage

- `probe` never prints `generic_turn_link=...`
  The live VK provider run never reached transport-ready credentials. Inspect
  the probe output and `artifacts/windows-desktop-live-vk/` first.
- Windows helper says `clientd` is missing required capability
  The bundled desktop sidecar is stale or the GUI was not started through
  `scripts/run-windows-gui-shell.ps1`.
- Desktop helper fails before `ready`
  Export diagnostics with `windows-desktop-generic-turn.ps1 diagnostics` and
  inspect the latest session failure stage.
- Desktop session reaches `ready`, but public traffic dies after enabling
  `WireGuard`
  The persistent route points to the wrong TURN host, or the imported
  `desktop1-windows.conf` profile no longer matches the validated exclusion
  settings in `docs/windows-desktop-wg-poc.md`.
