## Context

The repository now has two useful but still disconnected contracts:

- provider resolution can yield honest artifact families instead of flattening everything into `generic_turn`
- packaged hosts can report typed platform-tunnel capabilities and startup stages

That still leaves one missing architectural layer: the typed plan that turns a resolved artifact into a host-owned same-device execution path.

This gap matters because the next execution wave is not one transport:

- the current repo-owned path uses TURN plus the existing overlay runtime
- the first packaged system-tunnel paths are most practical with an app-native `WireGuard` engine
- future anti-DPI or foreign-core paths may look more like HTTPS-stream tunnels
- an in-call `WebRTC` data-channel path is materially different from TURN relay transport and should not be treated as a drop-in default for full-device VPN

If the repository skips this planning layer, upcoming Android and desktop platform-tunnel work will either:

- bake one `WireGuard-over-TURN` assumption into host and shell contracts
- or create a fake impression that any provider artifact can run through any carrier, engine, and host adapter combination

## Goals

- Define one typed runtime-execution-planning layer between provider artifacts and native same-device execution
- Keep `access_method`, `carrier_family`, `engine_family`, and `host_adapter` explicit and independently testable
- Preserve fail-closed support claims through an explicit compatibility matrix instead of an implicit `any x any` product promise
- Keep `add-17` and `add-18` honest by scoping their first supported ready paths to documented TURN-backed `wireguard_native` plans
- Allow future `webrtc_datachannel`, HTTPS-like tunnel, and foreign-core execution families without forcing them into the current `tunnel-server` shape
- Keep provider logic, byte-carrier logic, packet or proxy engine logic, and OS-specific packet capture ownership separate

## Non-Goals

- Implement `WebRTC` data-channel execution, `TrustTunnel`, or foreign-core proxy adapters in this change
- Promise that every artifact family can run through every carrier or engine family
- Make `WebRTC` data channels the default full-device VPN carrier for packaged hosts
- Replace the current TURN runtime or `tunnel-server` with a new universal backend in this change
- Hide engine-specific or server-specific operational differences behind one generic "VPN support" bit

## Decisions

### Decision: Introduce four explicit planning layers for host-owned execution

Each host-owned same-device execution path should be described by:

- `access_method`: what the provider artifact actually yields, for example `turn_credentials`, `webrtc_call_attach`, or another typed access surface
- `carrier_family`: how bytes move once execution starts, for example `turn_datagram`, `turn_dtls_overlay`, `webrtc_datachannel`, or an HTTPS-like tunnel family
- `engine_family`: what consumes that byte path locally, for example `wireguard_native`, `custom_packet_overlay`, `proxy_core_adapter`, or another documented engine family
- `host_adapter`: which local capture or injection boundary is used when execution needs one, for example `android_vpn_service`, `windows_wintun`, `linux_tun`, or `apple_network_extension`

The system should not collapse those concerns into one provider-specific or platform-specific mode string.

### Decision: Resolution stays separate from execution planning

Provider resolution continues to answer "what artifact did we get?".
Runtime execution planning answers "how can this host consume that artifact on this device?".

That keeps the useful boundary from the current architecture:

- providers resolve artifacts
- the control plane reports supported host-owned actions
- execution planning picks a concrete typed path only for those actions

### Decision: Compatibility is explicit and fail-closed

The repository should not imply an `any x any` matrix between access methods, carriers, engines, and host adapters.
Each supported execution path must be documented as an explicit compatibility edge.

If a host lacks one required edge, startup must fail before it claims readiness.
The host and shells must not synthesize a guessed fallback by inferring support from provider identifiers, platform names, or one successful path on another engine family.

### Decision: `wireguard_native` is the first supported packaged system-tunnel engine family

The first packaged Android and desktop ready paths should stay intentionally narrow:

- documented TURN-backed access methods
- documented TURN carrier families
- `wireguard_native` as the engine family
- one packaged host adapter per supported OS mode

This keeps `add-17` and `add-18` deliverable without forcing the repository to prove `WebRTC` or foreign-core semantics at the same time.

### Decision: `WebRTC` data-channel execution is experimental and non-default

An in-call `WebRTC` data-channel path may still be valuable for selected providers or stream/proxy modes, but it is not equivalent to the current TURN relay path and should not inherit system-tunnel support claims by default.

For this change, `webrtc_datachannel` remains a capability-gated carrier family that future changes must validate explicitly before any packaged host may treat it as more than an experimental execution path.

### Decision: Foreign-core runtimes stay behind generic engine families and explicit packaging rules

The repository may later integrate a foreign-core adapter for stealth or proxy-centric execution, but that should appear as an explicit engine family such as `proxy_core_adapter` rather than as provider-specific branching.

That keeps the contract stable even if the implementation later chooses one concrete runtime family such as `sing-box`, `Xray`, or another operator-approved core.

### Decision: Carrier families keep distinct remote endpoint roles

The current `tunnel-server` remains the remote endpoint family for documented TURN-backed carriers.
Future `WebRTC` or HTTPS-like carriers must define their own remote endpoint families and verification paths instead of pretending that the existing server already satisfies those roles.

This prevents the repository from mislabeling the current server as a universal VPN backend when it is really one carrier-specific relay and upstream bridge.

## Risks / Trade-offs

- The vocabulary is broader than the current runtime and could invite speculative abstraction if later changes are not kept narrow
- If the compatibility matrix is underspecified, shells or docs may still overclaim support from one successful path
- Foreign-core adapters can bring large policy and lifecycle surfaces that compete with the repo-owned runtime model
- `WebRTC` data channels remain attractive as a stealth carrier but can create buffering, framing, and lifecycle problems that do not match full-device VPN assumptions
- Adding a new planning layer increases control-plane surface area and therefore rollout complexity across hosts and shells

## Validation Plan

- Add a new `runtime-execution-planning` capability spec plus deltas for provider artifacts, control plane, and platform tunnel support claims
- Keep the first supported packaged system-tunnel paths explicitly scoped to TURN-backed `wireguard_native` plans in spec text
- Require explicit capability and plan metadata before later changes may advertise `webrtc_datachannel` or foreign-core execution
- Update operator and architecture docs alongside future implementation changes so server-role claims stay carrier-specific
- `openspec validate add-22-runtime-execution-planning --strict --no-interactive`
