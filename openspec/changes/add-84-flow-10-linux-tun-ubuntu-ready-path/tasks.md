## 1. Linux runtime lifecycle
- [ ] 1.1 Define the first concrete Ubuntu `linux_tun` lifecycle under the
      packaged desktop host boundary
- [ ] 1.2 Define how strict TURN-backed `wireguard_native` lease materialization
      and runtime attach are reused for Linux startup
- [ ] 1.3 Define fail-closed cleanup semantics for failures after route
      preparation, host bring-up, or runtime attach

## 2. Route policy and dataplane proof
- [ ] 2.1 Define the first Linux underlay-route policy slice as
      `preserve_active_local_network`
- [ ] 2.2 Define fail-closed behavior for unsafe control-traffic preservation
      and Linux route-policy preparation
- [ ] 2.3 Define Linux dataplane readiness evidence before `ready=true`

## 3. Validation
- [ ] 3.1 Define Ubuntu VM verification expectations for the first `linux_tun`
      ready path
- [ ] 3.2 Run `openspec validate add-84-flow-10-linux-tun-ubuntu-ready-path --strict --no-interactive`
