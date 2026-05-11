## 1. WB candidate contract

- [ ] 1.1 Extend `wb-stream-attach-runtime` so the first explicit generic WB
      same-device candidate explicitly uses
      `webrtc_call_attach + webrtc_datachannel + custom_packet_overlay`.
- [ ] 1.2 Define the fail-closed boundary between WB attach bootstrap present,
      datachannel candidate known, and payload-ready runtime still unverified.
- [ ] 1.3 Define that documenting the WB datachannel candidate does not exclude
      a later sibling provider-specific room-data-plane candidate.

## 2. Generic tuple alignment

- [ ] 2.1 Extend `webrtc-datachannel-carrier` so the generic tuple can be
      consumed from the room-authenticated WB attach contour without leaking raw
      bootstrap material and without exhausting the whole WB attach surface.
- [ ] 2.2 Define that WB uses the provider-owned call endpoint and does not
      downgrade the candidate into `turn_credentials`.

## 3. Control-plane and verification gate

- [ ] 3.1 Extend `client-control-plane` so hosts can report the WB datachannel
      candidate explicitly as experimental without implying it is the only
      future WB same-device path.
- [ ] 3.2 Define the evidence bar: repo-owned payload over the documented WB
      datachannel carrier, not just room join, relay allocation, or channel
      open.

## 4. Validation

- [ ] 4.1 Run `openspec validate add-81-flow-6-wb-stream-webrtc-datachannel-candidate --strict --no-interactive`.
