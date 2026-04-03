## Context

The base runtime change deliberately supports only one narrow startup policy so the first end-to-end path can land safely.
The repository still exposes transport controls in config and CLI, and the product contract expects those controls to become real behavior.
The canonical runtime contract already lives in `tunnel-client-runtime`, so this change must modify that capability instead of creating a second competing runtime spec.

## Goals

- Support explicit TURN transport selection for one-session client runtime startup.
- Support DTLS-on and DTLS-off client runtime paths explicitly.
- Support a narrow, deterministic outbound bind target contract for TURN transport setup.
- Keep compatibility evidence and integration coverage aligned with the expanded supported matrix.

## Non-Goals

- Introducing multi-connection supervision in the same change.
- Adding new providers.
- Hiding unsupported combinations behind auto-fallback behavior.
- Supporting interface-name pinning semantics in the same change.
- Changing the local client listener from UDP to TCP.

## Decisions

- The canonical capability for this change is `tunnel-client-runtime`; `05` modifies that contract instead of introducing a separate runtime capability.
- The supported one-session matrix for this change is:
  - local listener remains UDP for every supported combination
  - `mode=udp`, `mode=tcp`, and `mode=auto` are supported TURN transport selections
  - `dtls=true` and `dtls=false` are supported peer relay selections
  - `mode=auto` normalizes to the documented default TURN transport path for the provider/runtime slice; until another provider contract says otherwise, that default remains UDP
- `mode=tcp` means TCP between the client and the TURN server only. It does not change the local listener or the peer-facing relay semantics.
- `dtls=false` means a provider-agnostic plain datagram path between the TURN relay allocation and the configured UDP peer. The runtime must not silently force DTLS on.
- `bind-interface` in this change supports only a literal local IP address for outbound TURN socket binding or dialing. Non-IP values, including interface names, remain unsupported and fail closed.
- A valid literal bind target that cannot actually be applied fails explicitly during outbound transport setup. The runtime must not retry with an implicit fallback bind.
- The runtime should build an explicit transport plan in `internal/session` before transport startup:
  - TURN transport: UDP packet socket or TCP stream wrapped with TURN/STUN framing
  - peer relay adapter: DTLS or plain datagram
  - outbound bind target: empty or literal local IP
- Stage taxonomy should remain explicit. `dtls_handshake` is used only when DTLS is enabled; transport-neutral peer setup errors should use a distinct stage such as `peer_setup`.
- Each newly supported combination must have targeted integration coverage on deterministic `generic-turn` infrastructure, and every VK-backed supported slice claim must refresh `vk-runtime-compatibility` evidence.

## Risks / Trade-offs

- Supporting more policy combinations increases the test matrix quickly.
  Mitigation: document the supported one-session matrix explicitly instead of implying the full Cartesian product.
- Interface pinning behavior can be platform-sensitive.
  Mitigation: keep `bind-interface` limited to literal local IP values in this change and defer interface-name semantics.
- DTLS-off support can easily rot into bool-driven branching inside one transport runner.
  Mitigation: introduce a transport plan and transport-specific factories instead of widening the current runner with ad hoc conditionals.
- Expanded runtime behavior can drift away from the VK compatibility contract.
  Mitigation: treat `vk-runtime-compatibility` refresh as a required verification surface, not optional follow-up documentation.

## Migration Plan

1. Modify `tunnel-client-runtime` to define the expanded supported one-session matrix and remaining unsupported combinations.
2. Introduce transport planning and separate TURN transport / peer relay setup paths.
3. Extend deterministic harness coverage for TURN-over-TCP and DTLS-off startup.
4. Refresh VK runtime compatibility evidence for the supported VK-backed combinations.
5. Document the final supported matrix and explicit remaining gaps.
