## 1. Discovery and contract

- [ ] 1.1 Document the non-secret WB attach bootstrap contract and
      prerequisites from live evidence.
- [ ] 1.2 Define the host-owned redaction boundary for access token, room
      token, signaling endpoint, and room-authenticated bootstrap state.
- [ ] 1.3 Define the fail-closed boundary between `open_room`,
      `webrtc_call_attach`, and rejected `generic_turn` reinterpretation.
- [ ] 1.4 Define that the WB attach boundary stays carrier-neutral and does not
      pre-choose between a generic datachannel tuple and a provider-specific
      room-data-plane candidate.

## 2. Control-plane and artifact planning

- [ ] 2.1 Add `wb-stream-attach-runtime` spec coverage for room-authenticated
      attach bootstrap and support gating.
- [ ] 2.2 Extend `provider-runtime-artifacts` so provider-issued ICE/TURN lines
      do not imply `turn_credentials` for conference artifacts.
- [ ] 2.3 Extend `client-control-plane` so missing verified execution tuples
      fail before `ready=true` with no silent fallback.

## 3. Evidence gate

- [ ] 3.1 Define the verification bar for WB same-device attach support:
      repo-owned payload over the provider call endpoint, no secret leakage,
      explicit execution tuple.
- [ ] 3.2 Validate `add-80-flow-6-wb-stream-same-device-attach-path` with
      `openspec validate add-80-flow-6-wb-stream-same-device-attach-path --strict --no-interactive`.
