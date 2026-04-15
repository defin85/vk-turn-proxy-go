## 1. Contract and artifact planning
- [ ] 1.1 Add the new `webrtc-datachannel-carrier` capability spec for the first repo-owned non-WireGuard execution path
- [ ] 1.2 Extend provider/runtime artifact requirements so only eligible attachable artifacts may advertise `webrtc_call_attach` and the `webrtc_datachannel + custom_packet_overlay` execution tuple
- [ ] 1.3 Extend the client control plane contract for explicit negotiation, startup, and fail-closed reporting of the experimental WebRTC datachannel path

## 2. Runtime and attach implementation
- [ ] 2.1 Implement host-owned attach materialization for `webrtc_call_endpoint` without exposing raw attach/session secrets through ordinary reads
- [ ] 2.2 Implement the repo-owned `webrtc_datachannel + custom_packet_overlay` runtime path and its startup lifecycle
- [ ] 2.3 Keep the path capability-gated and non-default until repo-owned evidence proves it can carry traffic safely

## 3. Evidence and documentation
- [ ] 3.1 Add verification that proves real payload traffic crosses the repo-owned WebRTC datachannel path instead of only proving room attach or channel open
- [ ] 3.2 Add fail-closed coverage for missing attach target, missing capability, channel bring-up failure, and runtime-attach failure
- [ ] 3.3 Document operator-facing scope, experimental status, and the limits relative to TURN-backed `wireguard_native`

## 4. Validation
- [ ] 4.1 Run `openspec validate add-24-webrtc-datachannel-runtime-path --strict --no-interactive`
