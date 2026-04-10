# Live VK Two-Step WG E2E

This document defines the repo-owned two-step workflow for running a real
`WireGuard` session over the current `udp -> udp` transport slice when the live
VK provider requires interactive browser continuation.

Unlike the unattended smoke in `docs/wg-over-transport-e2e.md`, this flow does
not preflight VK with a separate `probe` run. It starts one `clientd` session,
waits until that exact session reaches `challenge_required`, and later
continues the same `challenge_id`.

## Scope

This workflow proves:

- live VK provider resolution can pause in `challenge_required`
- the operator can complete the VK browser challenge and continue the same
  control-plane session
- the continued session can reach runtime `ready`
- temporary `WireGuard` interfaces can pass real traffic over the repo-owned
  transport path

This workflow does not claim:

- unattended live VK resolution
- repo-owned TURN provisioning
- repo-owned system-tunnel or TUN/Wintun/VpnService support

## Required inputs

- `PROVIDER_LINK='https://vk.com/call/join/<invite>'`
- local `sudo` access in WSL
- SSH access to `vk-turn-proxy-go`
- local browser support for the controlled VK continuation browser
- `wg`, `ip`, `ping`, `ssh`, `scp`, `sudo`, `jq`, `curl` installed locally
- `wg`, `ip`, `sudo`, `ss` installed on the VPS

For an actual human solve, keep `VK_PROVIDER_BROWSER_HEADLESS` unset or set it
to `false`.

## Step 0: Check

```bash
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-live-vk.sh check
```

That verifies:

- local and remote privileged access
- local browser availability for provider continuation
- local and remote `WireGuard` kernel support
- required ports and interface names are free for a fresh run

## Preferred path: One interactive run

```bash
PROVIDER_LINK='https://vk.com/call/join/<invite>' \
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-live-vk.sh run
```

That path:

1. starts the same persisted `clientd` session as the two-step flow
2. waits until VK reaches `challenge_required`
3. keeps the controlled browser open for captcha, login, and join steps
4. waits for the operator to type `continue` in the same terminal
5. continues the same `challenge_id`
6. runs the WG-over-transport smoke to `ready`

Use this when you want one terminal command and one interactive pause.

## Step 1: Start

```bash
PROVIDER_LINK='https://vk.com/call/join/<invite>' \
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-live-vk.sh start
```

The script:

1. builds `linux/amd64` artifacts
2. creates a persistent run state directory under `artifacts/wg-live-vk/`
3. starts local `clientd` on loopback
4. starts one interactive VK session through `clientd`
5. waits for that session to reach `challenge_required`
6. writes `session.json`, `challenge.json`, `diagnostics.json`, WG keys, and
   `clientd.log` into the run state directory
7. prints the exact `continue` command for that same run

At this point the controlled browser is already tied to that session. Complete
the VK challenge in that browser before moving to step 2.

## Step 2: Continue

```bash
STATE_DIR='/abs/path/from-step-1' \
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-live-vk.sh continue
```

That step:

1. verifies the saved `clientd` session is still in `challenge_required`
2. configures temporary `WireGuard` interfaces locally and on the VPS
3. deploys and starts `tunnel-server` on the VPS
4. calls `POST /v1/challenges/<id>/continue`
5. waits for the same session to reach `ready`
6. pings the remote WG IP through the tunnel
7. saves `wg show` output and updated diagnostics into the run state directory

The script intentionally keeps the run state, `clientd`, and the temporary
networking in place after a successful `continue`, so the operator can inspect
the artifacts before cleanup.

## Cleanup

```bash
STATE_DIR='/abs/path/from-step-1' \
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-live-vk.sh cleanup
```

That stops the saved session when possible, tears down the temporary local and
remote `WireGuard` interfaces, stops the remote `tunnel-server`, and leaves the
artifact directory in place for inspection.

## Handoff to a physical Android phone

If you want the live VK-derived `generic-turn://...` link on a physical Android
device instead of the local desktop `WireGuard` smoke, resolve the invite here
first and then hand the printed `generic_turn_link` to the phone workflow in
`docs/android-wg-phone-poc.md`.

## Default paths and ports

- `clientd`: `127.0.0.1:37777`
- local tunnel ingress: `127.0.0.1:39000`
- remote tunnel listen: `0.0.0.0:56040`
- local WG listen: `51870`
- remote WG listen: `51871`
- local WG interface: `vktplivec`
- remote WG interface: `vktplives`
- local WG address: `10.231.1.2/24`
- remote WG address: `10.231.1.1/24`

Override them with environment variables only when the defaults collide with
the current machine state.
