## Context

`add-22-runtime-execution-planning` fixed the first packaged system-tunnel
target to a strict planning tuple:

- `access_method=turn_credentials`
- `carrier_family=turn_datagram`
- `engine_family=wireguard_native`
- one packaged `host_adapter`

That decision was intentionally narrower than the current runtime.
The current repo-owned same-device path is still:

- `access_method=turn_credentials`
- `carrier_family=turn_dtls_overlay`
- `engine_family=custom_packet_overlay`
- no packaged host adapter

The repository also has external WireGuard proofs above the current runtime, but
those are explicitly compatibility workflows that still depend on an external
WireGuard app or operator-managed interface.

What is missing is the prerequisite layer that turns a resolved `generic_turn`
artifact into a repo-owned, startable strict `turn_datagram + wireguard_native`
path without leaking raw WireGuard material into shell-facing state.

## Goals

- Keep `add-22` strict: the first packaged system-tunnel path stays
  `turn_datagram + wireguard_native`
- Define the host-owned materialization step between `turn_credentials` and a
  startable WireGuard carrier
- Keep the strict WireGuard carrier separate from the current overlay runtime
- Keep OS-specific packet capture and teardown inside Android/desktop host
  adapters instead of moving them into provider or transport packages
- Define the remote `turn_server` role for strict WireGuard-over-TURN startup
  explicitly
- Preserve fail-closed behavior when the materializer, carrier, or remote role
  is absent

## Non-Goals

- Delivering Android `android_vpn_service` readiness by itself
- Delivering Windows `windows_wintun` readiness by itself
- Reinterpreting the current `turn_dtls_overlay + custom_packet_overlay` path
  as if it already satisfied strict `turn_datagram + wireguard_native`
- Exposing raw WireGuard private keys, peer keys, or other carrier-secret
  material through ordinary shell-facing state
- Forcing one specific platform tunnel library choice for Android or desktop in
  this change

## Decisions

### Decision: A strict WireGuard path needs a new prerequisite layer, not just a host adapter

Android `VpnService` or desktop TUN/Wintun work is necessary but insufficient.
The strict `add-22` path also needs a repo-owned carrier and materialization
step that the repository does not currently implement.

### Decision: The host owns a secret-bearing WireGuard execution lease

Ordinary provider/runtime artifact reads may continue to expose
`turn_credentials`, action metadata, and execution plans.
However, a startable strict WireGuard path needs more than those ordinary
fields, including secret-bearing session material and concrete carrier state.

That state should be materialized and consumed inside the host boundary.
The shell should receive typed success or failure state, not a portable
WireGuard profile blob.

### Decision: The strict TURN datagram carrier stays separate from the current overlay runtime

The current runtime and the strict WireGuard carrier solve different problems
and use different invariants.
The repository must not silently reuse the DTLS overlay runtime and claim that
it has satisfied `carrier_family=turn_datagram`.

Support for one path must not imply support for the other.

### Decision: The remote endpoint family stays `turn_server`, but its strict WireGuard role must be explicit

`add-22` locked the first packaged path to `remote_endpoint_family=turn_server`.
That does not mean the current DTLS overlay server already satisfies the
required remote role for strict WireGuard-over-TURN startup.

This change therefore defines an explicit WG-over-TURN datagram role under the
same endpoint family instead of creating a fake new family or relying on the
existing overlay role by implication.

### Decision: Host adapters consume the carrier; they do not define it

Android and desktop packaged hosts may use different local tunnel primitives and
different embedded engine bindings, but they should consume the same strict
carrier/materialization contract.

That keeps:

- provider resolution separate from platform ownership
- carrier semantics separate from OS capture mechanics
- Android and desktop follow-on changes reusable instead of parallel one-off
  designs

### Decision: Verification must prove carrier truth, not just adapter truth

The repository must not claim support for strict packaged `wireguard_native`
startup merely because a `VpnService`, `Wintun`, or `linux_tun` interface comes
up.
Evidence has to prove the actual strict carrier path, secret-redaction rules,
and fail-closed behavior.

## Risks / Trade-offs

- This adds one more explicit layer between provider artifacts and packaged host
  startup, which increases rollout complexity
- If the lease boundary is underspecified, shells or diagnostics can still leak
  raw WireGuard material
- Keeping `turn_server` as the remote endpoint family can be misread as "the
  current overlay server already works" unless the strict role is worded
  carefully
- Future Android or desktop implementations may be tempted to bypass this
  carrier contract and reuse external WireGuard or overlay compatibility flows
- A broad carrier spec could invite premature generalization if it is not kept
  tightly scoped to the first strict WireGuard path

## Validation Plan

- Add a new `wireguard-turn-carrier` capability spec plus deltas for
  provider-runtime artifacts, the client control plane, and platform tunnel
  readiness
- Keep the proposal explicit that the strict carrier remains distinct from the
  current overlay runtime and external WireGuard compatibility flows
- Require repo-owned evidence for:
  - host-owned materialization without secret leakage
  - fail-closed startup when carrier prerequisites are missing
  - real WG traffic over the strict `turn_datagram` path
- Leave Android and desktop adapter-specific ready claims to follow-on changes
  after this prerequisite exists
- `openspec validate add-23-turn-datagram-wireguard-carrier --strict --no-interactive`
