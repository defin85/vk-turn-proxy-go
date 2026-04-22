# Windows Desktop Live VK Workflow

This document defines the repo-owned packaged Windows desktop workflow for
starting from a real VK invite inside the GUI, resolving it through the typed
provider-resolution handoff contract, and then starting the same-device desktop
runtime path.
It follows the canonical actor model from `docs/vk-invite-user-workflow.md`:
the call is created and shared outside the product, while the desktop app is
the invite-consumption and runtime-start surface.

The workflow keeps the current boundary explicit:

1. launch the packaged Windows desktop shell and bundled `clientd.exe`
2. resolve the live VK invite through the GUI and typed resolution resource
3. complete browser continuation if the provider requires it
4. start the same-device desktop session from the resolved handoff
5. enable the explicit external `WireGuard for Windows` compatibility path over
   that ready desktop transport session

## Scope

This workflow proves:

- the packaged Windows desktop GUI can resolve a real VK invite through the
  typed local-host contract
- the operator can complete browser continuation and reach `resolved` in the
  in-app resolution card
- the packaged Windows desktop host can start the normal same-device
  `generic-turn` runtime path from that resolved handoff
- the external `WireGuard for Windows` client can still use the desktop shell
  as local transport ingress after the live invite step

This workflow does not claim:

- repo-owned system VPN or `windows_wintun`
- unattended live VK resolution without an operator-driven browser step
- Android or iOS handoff behavior

## Required inputs

- a real VK invite URL
- a fresh Windows desktop bundle built through
  `./scripts/build-windows-gui-from-wsl.sh`
- the mirrored Windows-native bundle at
  `E:\Projects\vk-turn-proxy-go\dist\windows-gui`
- local Windows browser support for the provider challenge when VK requires it
- the official `WireGuard for Windows` client
- the validated `desktop1-windows.conf` profile format from
  `docs/windows-desktop-wg-poc.md`
- the VPS `wg-quick@wgvktp0.service` and `vk-turn-tunnel-wg.service` already
  running

## Step 1: Start the bundled desktop shell

Launch the repo-owned Windows helper from the mirrored checkout:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\run-windows-gui-shell.ps1
```

That starts a fresh bundled `clientd.exe`, waits for `/v1/host`, launches
`RelayDock.exe`, and stops the owned sidecar after the GUI exits.

## Step 2: Resolve the live VK invite in the GUI

In the desktop shell:

1. keep `Provider = vk`
2. paste the shared invite into `Provider link`
3. keep browser continuation enabled for the standard VK flow
4. review the non-secret runtime defaults in the profile editor
   (`Local UDP listen`, `Peer address`, transport mode, TURN overrides, and
   similar runtime knobs) only if you are acting as the operator/support owner
5. click `Resolve invite`

When the resolution succeeds, the resolution card shows:

- the typed `resolved` state
- the redacted TURN address
- the export expiry timestamp
- `Start on this device`
- `Copy handoff`

## Step 3: Complete browser continuation when required

If the resolution card enters `challenge_required`:

1. use the displayed provider URL or the host-opened browser session to
   complete the challenge
2. return to the desktop shell
3. click `Continue after browser step`
4. finish the VK browser flow past preview and click `Join`

The desktop shell keeps challenge continuation typed and host-driven.
It does not require CLI log parsing or manual secret reconstruction.
The session is not considered transport-ready while the browser flow remains at
preview-only state.

## Step 4: Add the Windows host route for the resolved TURN host

Before enabling `WireGuard for Windows`, add the persistent host route for the
current TURN host from the resolved desktop card.

You can take that host from either:

- the TURN address shown on the `resolved` card
- the explicit `Copy handoff` action if you need the full link for inspection

Resolve the current default gateway:

```powershell
$gw = (Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' | Sort-Object RouteMetric, InterfaceMetric | Select-Object -First 1).NextHop
```

Set the actual TURN host extracted from the resolved card, then add the
persistent route:

```powershell
$turnHost = '155.212.205.169'
route -p add $turnHost mask 255.255.255.255 $gw metric 1
route print $turnHost
```

This route must target the current TURN host from the live resolution, not a
stale host from an older run.

## Step 5: Start on this device

From the resolved desktop card, click `Start on this device`.

The host then:

- materializes the resolved handoff through the normal desktop runtime path
- reuses the non-secret runtime defaults already shown in the profile editor
- keeps the secret handoff link out of ordinary session reads and diagnostics

Wait until the session reaches `ready` in the desktop shell before enabling the
external `WireGuard` tunnel.

## Step 6: Enable the external compatibility WireGuard tunnel

Once the desktop session is `ready`:

1. import `desktop1-windows.conf` into `WireGuard for Windows` if needed
2. confirm `AllowedIPs` still stays `0.0.0.0/1, 128.0.0.0/1`
3. enable the imported tunnel
4. open any public IP check page in the browser

The `WireGuard` profile itself still follows the validated contract in
`docs/windows-desktop-wg-poc.md`.

## Optional: Capture throughput diagnostics during a speedtest

When the external tunnel may interrupt operator connectivity, start the
repo-owned capture helper before the throughput run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-desktop-throughput-capture.ps1 -DurationSeconds 180 -SampleIntervalSeconds 2
```

The helper:

- attaches to the latest desktop session unless you pin `-SessionId`
- writes artifacts under `artifacts\desktop-throughput-captures\<timestamp>\`
- stores raw `diagnostics` JSON snapshots and matching `.prom` metrics text
- keeps a compact `summary.csv` and `summary.ndjson` for later analysis
- when you reuse a fixed `-OutputDir` such as `...\latest`, it clears only the
  helper-managed artifacts in that directory before the new run starts

If you need to target one known session explicitly, pass its ID from the
desktop shell or control plane:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File E:\Projects\vk-turn-proxy-go\scripts\windows-desktop-throughput-capture.ps1 -SessionId <session-id> -DurationSeconds 180
```

## Failure triage

- The resolution never reaches `resolved`
  Inspect the failure stage shown on the desktop resolution card instead of
  falling back to CLI guesses.
- The resolution stays in `challenge_required`
  The browser step was not completed or the operator did not click
  `Continue after browser step`.
- `Start on this device` fails before `ready`
  Export diagnostics from the desktop shell and inspect the latest session
  failure stage.
- Desktop session reaches `ready`, but public traffic dies after enabling
  `WireGuard`
  The persistent route points to the wrong TURN host, or the imported
  `desktop1-windows.conf` profile no longer matches the validated exclusion
  settings in `docs/windows-desktop-wg-poc.md`.
- You need the raw short-lived handoff secret for support or another device
  Use `Copy handoff` from the resolved desktop card. That explicit export
  remains optional and is not required for same-device startup.
