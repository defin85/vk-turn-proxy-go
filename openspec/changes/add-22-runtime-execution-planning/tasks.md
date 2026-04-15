## 1. Runtime execution planning contract
- [x] 1.1 Add the new `runtime-execution-planning` capability so host-owned same-device execution plans name `access_method`, `carrier_family`, `engine_family`, and optional `host_adapter` explicitly
- [x] 1.2 Define the fail-closed compatibility-matrix rules so supported execution paths are explicit edges instead of an implied `any x any` promise
- [x] 1.3 Keep the first packaged Android and desktop system-tunnel support claims scoped to documented TURN-backed `wireguard_native` plans

## 2. Provider artifact and control-plane surface
- [x] 2.1 Extend `provider-runtime-artifacts` so resolved artifacts advertise typed access methods for host-owned same-device actions
- [x] 2.2 Extend `client-control-plane` so hosts negotiate runtime-execution-planning explicitly and return typed execution plans for supported same-device actions
- [x] 2.3 Define plan-selection and unsupported-plan failure behavior so hosts and shells do not infer compatibility from provider or platform heuristics

## 3. Carrier and engine family boundaries
- [x] 3.1 Define the documented carrier families and the rule that each carrier keeps its own remote endpoint ownership instead of reusing the current `tunnel-server` by implication
- [x] 3.2 Define capability-gated rules for experimental `webrtc_datachannel` plans and explicit packaging or verification requirements for foreign-core engine families
- [x] 3.3 Keep host-owned packet capture, route control, and DNS-bypass responsibilities inside the packaged host adapter boundary even when future engine families change

## 4. Verification and follow-on planning
- [x] 4.1 Update architecture and operator docs so they distinguish the current TURN-backed server role from future `WebRTC` or HTTPS-like remote endpoints
- [x] 4.2 Record the follow-on implementation slices needed for TURN-backed `wireguard_native`, experimental `webrtc_datachannel`, and foreign-core engine families without claiming unsupported combinations
- [x] 4.3 Run `openspec validate add-22-runtime-execution-planning --strict --no-interactive`
