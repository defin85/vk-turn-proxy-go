# WireGuard Native Remote Ingress

This runbook defines the VPS-side ingress for strict
`turn_datagram + wireguard_native` platform tunnel startup.

## Decision

The first implementation uses a dedicated raw-WireGuard datagram ingress:

- `56040/udp` remains the DTLS/custom-overlay listener.
- `56042/udp` is the raw WireGuard listener.
- No listener may accept both DTLS overlay traffic and raw WireGuard datagrams
  unless a repo-owned UDP protocol multiplexer is implemented and verified.

## VPS Service

The canonical live service is:

```text
vk-turn-tunnel-wg-plain.service
```

Expected command line:

```bash
/opt/vk-turn-proxy-go/bin/tunnel-server \
  -listen 0.0.0.0:56042 \
  -peer-mode plain \
  -egress udp \
  -connect 127.0.0.1:51871 \
  -metrics-listen 127.0.0.1:56043 \
  -log-level info
```

The existing DTLS/custom-overlay service remains separate:

```text
vk-turn-tunnel-wg.service
```

Expected command line:

```bash
/opt/vk-turn-proxy-go/bin/tunnel-server \
  -listen 0.0.0.0:56040 \
  -peer-mode dtls \
  -egress udp \
  -connect 127.0.0.1:51871 \
  -metrics-listen 127.0.0.1:56041 \
  -log-level info
```

## Firewall

External UDP ingress must allow both documented ports:

- `56040/udp` for DTLS/custom-overlay.
- `56042/udp` for strict raw-WireGuard ingress.

Metrics listeners `56041` and `56043` stay bound to `127.0.0.1` and must not be
opened externally.

## Verification

Use the canonical SSH alias:

```bash
ssh vk-turn-proxy-go "systemctl --no-pager --plain status vk-turn-tunnel-wg.service vk-turn-tunnel-wg-plain.service"
ssh vk-turn-proxy-go "ss -lunp | grep -E ':(56040|56042|51871)\\b'"
```

Acceptance evidence for this runbook:

- `vk-turn-tunnel-wg.service` is active with `-peer-mode dtls` on
  `0.0.0.0:56040`.
- `vk-turn-tunnel-wg-plain.service` is active with `-peer-mode plain` on
  `0.0.0.0:56042`.
- The WireGuard UDP listener is present on `51871`.
- Windows and Android platform-tunnel startup results expose
  `remote_ingress.protocol=raw_wireguard_datagram`,
  `remote_ingress.address=176.109.104.105:56042`, and
  `remote_ingress.isolation=dedicated`.
