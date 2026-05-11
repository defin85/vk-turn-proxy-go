## 1. Linux runtime lifecycle
- [x] 1.1 Define the first concrete Ubuntu `linux_tun` lifecycle under the
      packaged desktop host boundary
- [x] 1.2 Define how strict TURN-backed `wireguard_native` lease materialization
      and runtime attach are reused for Linux startup
- [x] 1.3 Define fail-closed cleanup semantics for failures after route
      preparation, host bring-up, or runtime attach

## 2. Route policy and dataplane proof
- [x] 2.1 Define the first Linux underlay-route policy slice as
      `preserve_active_local_network`
- [x] 2.2 Define fail-closed behavior for unsafe control-traffic preservation
      and Linux route-policy preparation
- [x] 2.3 Define Linux dataplane readiness evidence before `ready=true`

## 3. Validation
- [x] 3.1 Define Ubuntu VM verification expectations for the first `linux_tun`
      ready path
- [x] 3.2 Run `openspec validate add-84-flow-10-linux-tun-ubuntu-ready-path --strict --no-interactive`
- [x] 3.3 Run Go verification for the concrete Linux lifecycle and
      control-plane wiring:
      `go test -count=1 ./internal/linuxdesktophost ./pkg/clientcontrol ./cmd/clientd`,
      `go test ./...`, and `go build ./...`
- [x] 3.4 Capture live Ubuntu non-elevated host evidence that `linux_tun`
      remains fail-closed with `missing_prerequisite=permission`
- [x] 3.5 Capture elevated Ubuntu VM `ready=true` smoke evidence through the
      packaged `/v1/platform-tunnels/start` path. Evidence on `ubuntu-vmware`
      with a fresh `cmd/clientd` binary and compatible `wireguard_native_v1`
      transport profile:
      `/v1/host` reports `linux_tun available=true`,
      `support_state=supported`, and `transport_profile.state=compatible`;
      provider/transport candidate `ptc-162fb0b8aabde33d` is `startable`
      for `turn_credentials + turn_datagram + wireguard_native + linux_tun`;
      `/v1/platform-tunnels/start` returns `ready=true`,
      `stage=dataplane_verify`, remote ingress
      `176.109.104.105:56042`, fresh WireGuard handshake, positive traffic
      deltas (`rx=6380`, `tx=3616`), expected egress
      `176.109.104.105`, and bidirectional traffic verified. Stop returned
      `stopped=true`, and post-stop checks showed no `rdtun0` interface and
      no residual `rdtun0`/split-default/control-underlay routes.
