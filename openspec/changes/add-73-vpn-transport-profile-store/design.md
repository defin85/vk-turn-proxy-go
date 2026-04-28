## Context

`add-71-flow-1-wireguard-native-ingress-contract` removed the unsafe hidden
Android `phone1.conf` prerequisite and moved the material into an explicit UI
import. That fixes the immediate fail-closed problem, but it leaves the
architecture centered on one WireGuard file.

The risk is not only naming. A path from Flutter/Kotlin into the Go host is a
low-level implementation detail. If that becomes the product API, every future
transport has to masquerade as a file or force another one-off bridge.

## Goals / Non-Goals

- Goals:
  - Introduce a transport-profile store as the stable product and control-plane
    concept.
  - Keep secret-bearing material host-owned and redacted from ordinary shell
    state, events, and diagnostics.
  - Let runtime execution plans declare material requirements independently
    from carrier, engine, and host adapter names.
  - Make WireGuard `.conf` an adapter for one profile type instead of the
    generic configuration model.
  - Preserve the current strict fail-closed behavior when required material is
    missing, invalid, expired, or incompatible with the selected plan.
- Non-Goals:
  - Do not implement additional VPN engines in this change.
  - Do not add cloud sync or cross-device transport-profile sharing.
  - Do not expose raw private keys, peer secrets, or native file paths through
    ordinary control-plane reads.
  - Do not replace provider profiles, provider runtime artifacts, or execution
    plans with transport profiles; they remain separate layers.

## Layer Model

- `Provider profile`: user/provider entry settings and authentication posture.
- `Provider runtime artifact`: resolved provider output such as `generic_turn`.
- `Runtime execution plan`: selected access method, carrier family, engine
  family, and host adapter.
- `VPN transport profile`: app-owned local material/profile configuration needed
  by one or more engine families.
- `Execution lease`: per-startup host-owned materialization that combines the
  selected artifact, execution plan, transport profile, policy, and remote
  endpoint.

The shell may manage profile metadata and invoke import/replace/forget actions.
The host owns validation, storage, redaction, materialization, and the execution
lease.

## Decisions

### Decision: Profiles are referenced by stable ids

Startup requests and plan metadata should use a `transport_profile_id` or a
host-reported default profile binding that resolves to a concrete profile id for
the selected host adapter and execution plan. They should not pass raw config
text, private keys, native paths, or platform file handles.

An implicit global default is not enough. The default binding has to be visible
through profile-store status, scoped to the compatible plan/host adapter, and
revalidated at startup.

### Decision: Profile kind is engine-specific but the store is generic

The first kind is `wireguard_native_v1`. Later kinds can be added through new
capability metadata such as `openvpn_userspace_v1`, `native_os_vpn_v1`, or a
provider-specific managed tunnel kind without changing the base store contract.

### Decision: Import adapters are separate from stored profile kind

WireGuard `.conf` is an import adapter that creates or replaces a
`wireguard_native_v1` profile. It is not the stored profile API and not the
cross-platform startup payload.

Accepted imports must be parsed and normalized at import time. A file extension
or MIME type can select an adapter, but it cannot be the validation proof.

### Decision: Diagnostics expose status, not secrets

Ordinary reads may show profile kind, display name, validation status,
fingerprint/hash of non-secret normalized content where useful, last import
time, compatibility status, and redacted error codes. They must not show raw
private keys, peer keys, preshared keys, full endpoint secrets, or app-private
filesystem paths.

Profile lifecycle operations should emit only redacted status and revision
metadata. Diagnostics can say why a profile is invalid or incompatible, but the
reason must not contain copied secret material.

### Decision: Missing profile material is a typed prerequisite

`transport_profile` should become its own platform-tunnel prerequisite, and
profile validation should have a distinct startup stage such as
`profile_validate`. Mapping a missing profile to `host_implementation` would
hide the operator action the UI can actually perform.

## Risks / Trade-offs

- Risk: keeping the current WireGuard-specific UI too long can make later
  engines feel bolted on. Mitigation: rename the product surface to VPN
  transport profiles now, while labeling the concrete type as WireGuard.
- Risk: a generic store can become too abstract. Mitigation: ship one concrete
  `wireguard_native_v1` path first and require typed adapters/tests for each
  later kind.
- Risk: storing secrets in plain app-private files may be insufficient for
  future threat models. Mitigation: make the storage backend explicit per
  platform and keep secure-storage/keystore hardening as a profile-store task,
  not as shell state.
- Risk: `AllowedIPs`, DNS, MTU, and route scope can mix material and policy.
  Mitigation: normalize profile-owned material separately from startup policy;
  conflicts fail closed with typed diagnostics.
- Risk: old tests may still assert file-path behavior. Mitigation: replace
  bridge tests with profile-id/status/materialization tests and keep
  file-path checks only inside platform-private storage tests.
- Risk: a "default profile" can become another hidden config. Mitigation:
  require default selection to be host-reported, profile-id-backed, scoped to
  the selected plan/adapter, and visible in redacted profile status.
- Risk: desktop keeps using `VKTP_WINDOWS_WIREGUARD_PROFILE` as product
  behavior while Android moves to the store. Mitigation: keep env/path inputs
  as development migration sources only and require desktop product startup to
  consume profile references before claiming profile-store support.

## Migration Plan

1. Add the profile-store schema, capabilities, and redacted status model.
2. Migrate the current Android explicit WireGuard import into a
   `wireguard_native_v1` profile record with an idempotent one-time migration
   from the legacy app-private file.
3. Change startup preparation from "is WireGuard path configured" to "is a
   compatible transport profile selected for this plan".
4. Keep a host-private storage backend that can still store the current
   normalized WireGuard material, but hide the path from shell-visible
   contracts and exclude the secret material from platform backup/sync unless a
   reviewed encrypted backup/export contract is added.
5. Update UI copy and tests from hidden/specific `phone1.conf` recovery to
   generic transport-profile setup with WireGuard as the first type.

## Open Questions

- Should one profile be selectable as the default per host adapter, per engine
  family, or per saved provider profile?
- Should transport profiles be edited as structured fields after import, or
  should the first version only support import/replace/forget plus validation?
- Which Android storage backend is required for private keys before Play
  release: app-private file with strict permissions, Android Keystore wrapping,
  or another secure-storage layer?
- Should desktop development env/default WireGuard paths be migrated into the
  same store automatically, or should desktop require explicit operator import
  when the product UI first exposes profile-store support?
