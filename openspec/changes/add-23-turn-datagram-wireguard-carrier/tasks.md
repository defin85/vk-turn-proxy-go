## 1. Carrier and materialization contract
- [ ] 1.1 Add the new `wireguard-turn-carrier` capability spec so the strict `turn_datagram + wireguard_native` path is documented separately from the current overlay runtime
- [ ] 1.2 Define the host-owned WireGuard execution lease and the rule that ordinary shell-facing reads do not expose raw WireGuard or carrier-secret material
- [ ] 1.3 Define the explicit remote `turn_server` role for WireGuard-over-TURN datagram termination instead of implying that the current DTLS overlay server already satisfies it

## 2. Cross-capability integration
- [ ] 2.1 Extend `provider-runtime-artifacts` so `generic_turn` artifacts can advertise strict `wireguard_native` planning metadata without leaking a startable carrier lease
- [ ] 2.2 Extend `client-control-plane` so same-device startup may materialize and consume the strict WireGuard carrier state internally while returning only typed success or failure state to shells
- [ ] 2.3 Extend `platform-tunnel-integration` so `ready=true` for packaged `wireguard_native` modes requires both the OS host adapter and the documented TURN-datagram carrier/materializer

## 3. Verification and follow-on coordination
- [ ] 3.1 Record the minimum repo-owned evidence needed for carrier bring-up, secret-redaction, fail-closed startup, and real WG traffic over the strict `turn_datagram` path
- [ ] 3.2 Record follow-on expectations for `add-17` and `add-18` so Android and desktop adapter work consume this prerequisite instead of replacing it with the current overlay runtime
- [ ] 3.3 Run `openspec validate add-23-turn-datagram-wireguard-carrier --strict --no-interactive`
