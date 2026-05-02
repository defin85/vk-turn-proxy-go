## 1. Contract and Planning

- [x] 1.1 Decide whether the first implementation uses a dedicated plain
  WireGuard ingress or an explicit UDP multiplexer, and record the decision in
  deployment docs.
- [x] 1.2 Extend runtime execution planning/materialization so
  `turn_datagram + wireguard_native` selects a raw-WireGuard ingress instead of
  reusing the DTLS overlay peer endpoint by default.
- [x] 1.3 Add diagnostics that show the selected ingress protocol, advertised
  address, and whether the endpoint is dedicated or mux-backed.

## 2. VPS and Runtime

- [x] 2.1 Add repo-owned VPS service/runbook support for the selected
  raw-WireGuard ingress, including firewall requirements.
- [x] 2.2 Keep the existing DTLS/custom-overlay listener on its documented DTLS
  endpoint and verify it is not silently repurposed.
- [x] 2.3 Add fail-closed runtime validation when a strict `wireguard_native`
  plan points at a DTLS-only endpoint without an explicit multiplexer.

## 3. Windows Host and UI

- [x] 3.1 Update Windows host defaults or provider materialization so
  `windows_wintun` starts against the selected raw-WireGuard ingress.
- [x] 3.2 Make readiness and diagnostics distinguish host attach, WireGuard
  handshake, and bidirectional data-plane evidence.
- [x] 3.3 Keep the desktop one-button flow intact: users should not manually edit
  peer, DTLS, or raw ingress settings in the normal path.

## 4. Android Host and UI

- [x] 4.1 Remove hidden Android `phone1.conf` staging from embedded-host and GUI
  packaging workflows, including environment/default profile fallbacks.
- [x] 4.2 Keep Android WireGuard material app-owned and explicit by adding a
  mobile UI/import path that stores the profile in app-private files and passes
  only that app-owned path to the embedded host.
- [x] 4.3 Keep the mobile Home action fail-closed when the selected strict
  Android WireGuard path has no supported execution plan or no explicit
  imported profile.
- [x] 4.4 Add a richer Android settings surface for profile metadata,
  validation detail, and replace/forget confirmation before production rollout.

## 5. Verification

- [x] 5.1 Add focused Go tests for endpoint selection and fail-closed protocol
  mismatch handling.
- [x] 5.2 Add or update Windows VM smoke coverage to prove fresh WireGuard
  handshake, Wintun received bytes, and egress IP through the VPS.
- [x] 5.3 Verify the existing DTLS/custom-overlay contour still targets the DTLS
  endpoint after the WireGuard-native ingress change.
- [x] 5.4 Verify Android debug APK contents reject packaged WireGuard seed
  assets.
- [x] 5.5 Run `openspec validate add-71-flow-1-wireguard-native-ingress-contract --strict --no-interactive`.

## Verification Notes

- Windows VM smoke coverage now fails closed unless the ready result includes
  `dataplane.host_attached=true`, a fresh WireGuard handshake, positive
  WireGuard RX/TX deltas, positive Wintun received bytes,
  `remote_egress_ip=176.109.104.105`, and bidirectional data-plane evidence.
- Live Windows VM execution was not rerun in this pass because
  `codex@192.168.32.142` was unreachable from WSL (`No route to host`).
