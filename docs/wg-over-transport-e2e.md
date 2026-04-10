# WireGuard Over Transport E2E

This document defines the repo-owned smoke path for running a real WireGuard
session over the currently supported `udp -> udp` transport slice.

## Scope

This workflow proves:

- local `WireGuard` can send encrypted UDP packets into `cmd/tunnel-client`
- `cmd/tunnel-client` can carry those packets over the configured real TURN path
- the VPS `cmd/tunnel-server` can forward them to a local `WireGuard` interface
- ICMP over the temporary WireGuard subnet succeeds end-to-end

This workflow does not claim:

- repo-owned TURN provisioning
- repo-owned TUN/TAP or system-tunnel integration
- product support beyond the current `udp -> udp` slice

## Required inputs

- either a real `generic-turn://...` link exported as `TURN_LINK`
- or a live provider input exported as `PROVIDER_NAME` and `PROVIDER_LINK`
- local `sudo` access in WSL
- SSH access to the project VPS alias `vk-turn-proxy-go`
- `wg`, `ip`, `ping`, `ssh`, `scp`, `sudo` installed locally
- `wg`, `ip`, `sudo` installed on the VPS

The script intentionally fails closed without an explicit real provider input.
It must not fall back to `turnlab` or any implicit TURN service for this real
run.

## One-time environment notes

- WSL kernel WireGuard support and VPS kernel WireGuard support are both
  required; the script probes that explicitly.
- The script expects passwordless `sudo` on the VPS.
- Local `sudo` can be passed non-interactively through
  `LOCAL_SUDO_PASSWORD=...`.

## Check-only

Use this before you have a real TURN link:

```bash
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-over-transport.sh --check-only
```

That path verifies:

- local and remote privileged access
- local and remote `WireGuard` kernel support
- required commands
- interface-name and port availability
- SSH alias resolution for the VPS public host

## Real run

```bash
TURN_LINK='generic-turn://user:pass@turn.example.test:3478' \
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-over-transport.sh
```

Or with a live provider link:

```bash
PROVIDER_NAME='vk' \
PROVIDER_LINK='https://vk.com/call/join/<invite>' \
LOCAL_SUDO_PASSWORD='...' \
  ./scripts/e2e-wg-over-transport.sh
```

The script:

1. builds `linux/amd64` artifacts through `scripts/build-go-matrix.sh`
2. runs a local provider preflight through `cmd/probe`
3. generates temporary WireGuard keys
4. deploys `tunnel-server` to the VPS
5. creates temporary `WireGuard` interfaces on both sides
6. starts remote `tunnel-server` with `-egress udp`
7. starts local `tunnel-client` with `-ingress udp -mode udp -dtls=true`
8. pings the remote WireGuard IP through the tunnel
9. prints `wg show` on both sides
10. tears everything down

## Live provider caveat

Live providers such as `vk` can still fail before transport startup.
The repo-owned script therefore runs `probe` first and stops before any remote
or WireGuard setup if provider resolution is not transport-ready.

For example, a VK invite may require captcha completion and return
`captcha_required` from provider preflight.
That is a valid fail-closed result, not a transport regression.

The current repo-owned end-to-end script is intentionally unattended after
provider preflight.
If a provider requires browser or captcha interaction, the script stops before
any WireGuard or VPS transport setup instead of trying to half-run the tunnel.

For live VK invites that need browser continuation, use the separate two-step
workflow in `docs/wg-live-vk-e2e.md` and `scripts/e2e-wg-live-vk.sh`.

## Defaults

- local tunnel ingress: `127.0.0.1:39000`
- remote tunnel listen: `0.0.0.0:56040`
- local WG listen: `51870`
- remote WG listen: `51871`
- local WG interface: `vktpe2ec`
- remote WG interface: `vktpe2es`
- local WG address: `10.231.0.2/24`
- remote WG address: `10.231.0.1/24`
- WG MTU: `1280`

Override those values with environment variables only when the defaults collide
with the current machine state.
