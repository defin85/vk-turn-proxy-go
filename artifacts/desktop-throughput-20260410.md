# Desktop Throughput Test Notes - 2026-04-10

## Scope

Manual Windows desktop throughput checks for the current live VK same-device path:

- packaged desktop GUI shell
- bundled `clientd.exe`
- live VK resolution in GUI
- `Start on this device`
- external `WireGuard for Windows`

This is the current PoC path, not repo-owned `windows_wintun`.

## Environment Notes

- Windows desktop shell showed `Windows Wintun: host implementation missing`
- That banner is expected for the current product slice
- `WireGuard for Windows` was enabled for throughput measurements
- Public IP changed after enabling `WireGuard`, so traffic was going through the tunnel
- Root `http://127.0.0.1:7777/metrics` returned `404`
- Session metrics were read from `GET /v1/sessions/<id>/diagnostics`

## Working Rules Confirmed

- The current live path requires `DTLS enabled = on`
- With `DTLS enabled = off`, traffic did not pass
- Increasing `Connections` improved throughput

## Measured Runs

### Run A

- config:
  - `DTLS = on`
  - `Connections = 1`
  - `turn_mode = udp`
  - `active_workers = 1`
- speed:
  - download: `3.54 Mbit/s`
  - upload: `1.54 Mbit/s`
- notes:
  - valid run through the tunnel
  - session counters increased during the test

### Run B

- config:
  - `DTLS = off`
- result:
  - traffic did not pass
- note:
  - do not use this variant for the current live VK desktop path

### Run C

- config:
  - `DTLS = on`
  - `Connections = 2`
  - `turn_mode = udp`
  - `active_workers = 2`
- speed:
  - download: `5 Mbit/s`
  - upload: `3 Mbit/s`
- notes:
  - valid run through the tunnel
  - throughput improved relative to `Connections = 1`

### Run D

- config:
  - `DTLS = on`
  - `Connections = 4`
  - `turn_mode = udp`
  - `active_workers = 4`
- speed:
  - download: `6.22 Mbit/s`
  - upload: `4.39 Mbit/s`
- notes:
  - valid run through the tunnel
  - throughput improved again relative to `Connections = 2`

## Interim Conclusion

At least one real bottleneck is in the single-worker / single-connection transport path.

Observed progression:

- `Connections = 1`: `3.54 / 1.54`
- `Connections = 2`: `5 / 3`
- `Connections = 4`: `6.22 / 4.39`

This does not prove that worker count is the only bottleneck, but it does show that the limit is inside the current transport path rather than the home ISP speed alone.

## Current Best Known Test Config

Use this config when resuming:

- `DTLS = on`
- `Connections = 4`
- `WireGuard for Windows = enabled`
- confirm public IP changes before each throughput run

## Next Step

Run a VPS-side CPU/process check during a live speedtest while keeping:

- `DTLS = on`
- `Connections = 4`

Command prepared for the next session:

```bash
ssh vk-turn-proxy-go "for i in {1..15}; do date '+%H:%M:%S'; ps -eo pid,pcpu,pmem,comm,args --sort=-pcpu | head -n 12; echo; ss -u -n -p | grep -E ':56040|:51820|:51871' || true; echo '---'; sleep 2; done"
```

Goal of the next step:

- see whether `tunnel-server`, WireGuard, or `ksoftirqd` on the VPS is saturating
- if VPS is not the bottleneck, test `MTU = 1280` next

## 2026-04-11 Follow-up

Follow-up measurements used the repo-owned capture helpers on Windows:

- throughput capture:
  `E:\Projects\vk-turn-proxy-go\artifacts\desktop-throughput-captures\latest`
- direct WireGuard health capture:
  `E:\Projects\vk-turn-proxy-go\artifacts\windows-wireguard-health\direct-wg-latest`

The capture helper was updated to clear old script-owned files before each run
when `-OutputDir` is reused, so the later `latest` runs are clean and do not
mix multiple sessions.

## Clean Over-Transport Result

The clean same-device desktop run with the current best-known PoC config kept:

- `DTLS = on`
- `Connections = 4`
- external `WireGuard for Windows`

Observed evidence:

- one clean capture window stayed in `ready` for the full `180s`
- `active_workers = 4` throughout the run
- `errors_written = 0`
- no startup or transport failures were recorded during the capture window

Throughput from the active traffic windows stayed in the same range as the
previous manual checks:

- download-like phase: about `7.47 Mbit/s`
- upload-like phase: about `6.94 Mbit/s`
- best `2s` interval: about `11.1 Mbit/s`

This confirmed that the current live desktop PoC path is stable enough to
measure, but its practical ceiling on this network remained around `7-8
Mbit/s`, not tens of megabits.

## VPS-Side Result

A detached VPS sampler was run during a live speedtest for the same clean
desktop session.

Observed evidence:

- `wgvktp0` stayed up for the whole sampled window
- the server kept `4` stable `tunnel-server` UDP sockets throughout the run
- no growth in sampled `tx_dropped` or `rx_errors` was observed on `wgvktp0`
- `sudo wg show` after the run still showed a live peer and recent handshake
- no clear CPU hotspot was observed from the sampler output

Conclusion from the server-side check:

- the VPS did not show a convincing bottleneck during these runs
- the throughput ceiling was therefore more likely in the Windows/WireGuard/ISP
  side of the path than in `tunnel-server` itself

## MTU 1280 Check

An additional run was attempted with `MTU = 1280` on the Windows WireGuard
profile.

The run intended for that comparison did not improve throughput:

- download-like phase: about `6.88 Mbit/s`
- upload-like phase: about `5.72 Mbit/s`
- best `2s` interval: about `10.06 Mbit/s`

This is worse than the clean baseline above.

Note:

- the capture still proved the transport session itself remained stable
- the WireGuard adapter was already down by the time of later inspection, so
  the MTU setting was not independently re-confirmed after the run

Practical conclusion:

- `MTU = 1280` is not a promising optimization for the current desktop PoC path

## Direct WireGuard A/B Check

A direct `WireGuard -> VPS` comparison was attempted by pointing the Windows
profile directly at:

```ini
Endpoint = 176.109.104.105:51871
```

The direct path did not establish a usable tunnel.

Windows-side evidence from the direct health capture:

- `wg.exe show` reported the correct peer endpoint
- transfer stayed at `0 B received, 1.45 KiB sent`
- `wg_show_has_handshake = False`
- `wintun_up_count = 0`
- `peer_ping_ok = False`
- `external_ping_ok = False`
- `gateway_ping_ok = True`

Server-side evidence at the same time:

- `wg show wgvktp0` on the VPS never received a new direct handshake
- the peer for `10.231.1.3/32` still showed the old loopback endpoint
  `127.0.0.1:*` from the transport-over-WireGuard PoC path

Practical conclusion:

- there is no evidence that direct Windows WireGuard to the VPS works on the
  current ISP path
- the old PoC `/32` route exclusions were not sufficient to explain the failure
- the failure happens before the VPS sees a direct handshake

## Current Conclusion

At this point further performance tuning inside the current application path has
low ROI on this network.

What is now established:

- the desktop app session can stay `ready` and carry real traffic
- increasing `Connections` from `1` to `4` helped relative to the single-worker
  path
- the current live desktop ceiling still clusters around `7-8 Mbit/s`
- VPS-side checks did not reveal a clear server bottleneck
- `MTU = 1280` did not improve the result
- direct WireGuard to the VPS did not complete a handshake at all

The most likely remaining bottleneck is outside the repo-owned transport logic:

- ISP filtering or shaping
- local router behavior
- Windows `WireGuard for Windows` path
- or a combination of those factors

## Recommended Next Step

Do not spend more time tuning the current external-WireGuard Windows PoC on the
same ISP path.

If this needs to be revisited later, use one of these two options:

- rerun the same A/B checks from a different internet connection such as mobile
  hotspot
- move effort to the repo-owned `windows_wintun` ready-path instead of the
  external `WireGuard for Windows` PoC
