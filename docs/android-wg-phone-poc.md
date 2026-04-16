# Android WireGuard Phone PoC

This document captures the validated Android operator workflow for routing real
phone traffic through `WireGuard` over the current `udp -> udp` transport slice.

The mobile app is only the local transport ingress in this path.
Device-wide VPN still belongs to the external `WireGuard` Android app.

## Scope

This workflow proves:

- the packaged Android app can expose the embedded host over loopback
- a physical Android phone can run a real transport session through that host
- the external `WireGuard` Android client can use `127.0.0.1:39000` as its UDP
  endpoint
- the VPS `WireGuard` gateway can NAT that traffic to the public internet

This workflow does not claim:

- repo-owned Android `VpnService`
- repo-owned mobile browser continuation for live VK captcha on-device
- one-app mobile VPN product support

## Required inputs

- the packaged Android app installed from `dist/mobile/android-gui-shell/`
- the official `WireGuard` Android app installed on the phone
- USB debugging enabled on the phone
- explicit user agreement to leave the Dart MCP-first UI loop and use `adb`
- Linux `adb` available inside WSL on `PATH` or at
  `~/.local/share/android-sdk/platform-tools/adb`
- Windows `adb.exe` remains an acceptable fallback only for Windows-specific
  workflows or when the device has not yet been paired into the WSL adb server
- a real `generic-turn://...` link
- the VPS `wg-quick@wgvktp0.service` and `vk-turn-tunnel-wg.service` already
  running

## One-time WireGuard profile

The working profile for the first phone lives outside the repository in:

- `~/.local/state/vk-turn-proxy-go/wg/phone1.conf`
- `~/.local/state/vk-turn-proxy-go/wg/phone1-qr.png`

That profile must keep this exclusion:

```ini
ExcludedApplications = com.defin85.mobile_gui_shell
```

Without that exclusion, `WireGuard` captures the transport app itself and the
path loops through `tun0`.
The practical symptom is `WireGuard` repeatedly logging
`Handshake did not complete after 5 seconds` while the phone-side transport
shows only `local_to_relay` traffic and no `relay_to_local`.

If the `WireGuard` profile changes, stop and recreate the phone transport
session.
Do not keep using a session that was started before the exclusion was present.

## Live TURN resolution

Live VK invite resolution is still desktop-driven.
The Android packaged host does not currently support the VK browser continuation
path on-device.

Resolve the invite on WSL/desktop first and extract the short-lived
`generic-turn` link:

```bash
VK_PROVIDER_BROWSER_HEADLESS=false \
go run ./cmd/probe \
  -provider vk \
  -link 'https://vk.com/call/join/<invite>' \
  -interactive-provider \
  -emit-generic-turn-link \
  -output-dir ./artifacts/phone-vk-resolve
```

After the human completes the browser challenge, `probe` prints:

```text
generic_turn_link=generic-turn://...
```

Use that exact value as `TURN_LINK` for the phone session.

## Repo-owned phone helper

After the user has explicitly agreed to an `adb` fallback, use the repo-owned
helper script to talk to the packaged embedded host over the WSL-visible `adb`:

```bash
python3 ./scripts/android-phone-session.py check
python3 ./scripts/android-phone-session.py status
TURN_LINK='generic-turn://...' \
  python3 ./scripts/android-phone-session.py start --replace-existing
python3 ./scripts/android-phone-session.py diagnostics --session-id latest
python3 ./scripts/android-phone-session.py stop --session-id latest
```

Equivalent `make` aliases exist:

```bash
make android-phone-check
make android-phone-status
TURN_LINK='generic-turn://...' make android-phone-start
make android-phone-diagnostics
make android-phone-stop
```

The helper script:

- finds the physical phone through `adb`
- auto-launches `com.defin85.mobile_gui_shell` if needed
- discovers the current embedded-host loopback port inside the app process
- talks to `/v1/host`, `/v1/sessions`, and `/v1/sessions/<id>/diagnostics`
- starts or stops the phone transport session without manual UI editing
- reports whether the active `WireGuard` VPN excludes the mobile app UID

## Reproducible run

1. Install the latest APK on the phone.
2. Import the current `phone1.conf` into `WireGuard`.
3. Enable the `phone1` tunnel in `WireGuard`.
4. Resolve a live `generic-turn://...` link on WSL with `cmd/probe`.
5. Start or restart the phone transport session:

```bash
TURN_LINK='generic-turn://...' \
  python3 ./scripts/android-phone-session.py start --replace-existing
```

6. Confirm the helper reports `state=ready`.
7. Confirm the phone has public reachability:

```bash
adb shell ping -c 3 -W 2 10.231.1.1
adb shell ping -c 3 -W 2 1.1.1.1
```

8. Open any public IP check page in the phone browser.

## Failure triage

- `wireguard_excludes_mobile_app=no`
  The imported `WireGuard` profile is wrong. Re-import the profile with
  `ExcludedApplications = com.defin85.mobile_gui_shell`, then recreate the
  phone session with `--replace-existing`.
- `browser_continuation_failed`
  The Android app tried to resolve live VK directly. That path is still
  unsupported on-device; use desktop `cmd/probe` first.
- `ready` session but stale traffic counters
  Recreate the session. A transport session started before the route exclusion
  was present can stay logically `ready` while its data plane is already wrong.
- no embedded host found
  Open the mobile app once on the phone and rerun the helper.
