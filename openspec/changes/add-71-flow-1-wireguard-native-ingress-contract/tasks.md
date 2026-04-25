## 1. Contract and Planning

- [ ] 1.1 Decide whether the first implementation uses a dedicated plain
  WireGuard ingress or an explicit UDP multiplexer, and record the decision in
  deployment docs.
- [ ] 1.2 Extend runtime execution planning/materialization so
  `turn_datagram + wireguard_native` selects a raw-WireGuard ingress instead of
  reusing the DTLS overlay peer endpoint by default.
- [ ] 1.3 Add diagnostics that show the selected ingress protocol, advertised
  address, and whether the endpoint is dedicated or mux-backed.

## 2. VPS and Runtime

- [ ] 2.1 Add repo-owned VPS service/runbook support for the selected
  raw-WireGuard ingress, including firewall requirements.
- [ ] 2.2 Keep the existing DTLS/custom-overlay listener on its documented DTLS
  endpoint and verify it is not silently repurposed.
- [ ] 2.3 Add fail-closed runtime validation when a strict `wireguard_native`
  plan points at a DTLS-only endpoint without an explicit multiplexer.

## 3. Windows Host and UI

- [ ] 3.1 Update Windows host defaults or provider materialization so
  `windows_wintun` starts against the selected raw-WireGuard ingress.
- [ ] 3.2 Make readiness and diagnostics distinguish host attach, WireGuard
  handshake, and bidirectional data-plane evidence.
- [ ] 3.3 Keep the desktop one-button flow intact: users should not manually edit
  peer, DTLS, or raw ingress settings in the normal path.

## 4. Verification

- [ ] 4.1 Add focused Go tests for endpoint selection and fail-closed protocol
  mismatch handling.
- [ ] 4.2 Add or update Windows VM smoke coverage to prove fresh WireGuard
  handshake, Wintun received bytes, and egress IP through the VPS.
- [ ] 4.3 Verify the existing DTLS/custom-overlay contour still targets the DTLS
  endpoint after the WireGuard-native ingress change.
- [ ] 4.4 Run `openspec validate add-71-flow-1-wireguard-native-ingress-contract --strict --no-interactive`.
