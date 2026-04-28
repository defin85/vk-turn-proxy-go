## Context

The current profile-store workflow is safe but file-centric. It lets the shell
submit a WireGuard `.conf` through an import adapter and later refer to the
result by profile id. Operators still cannot create or edit the profile from
the app, and small corrections require leaving the product UI.

The new editor must not weaken the add-73 boundary. The shell may collect a
draft and invoke host operations, but the host remains the source of truth for
validation, storage, redaction, default bindings, and startup materialization.

## Goals / Non-Goals

- Goals:
  - Provide a structured editor for `wireguard_native_v1` transport profiles.
  - Let operators create profiles without a `.conf` file.
  - Let operators update non-secret and secret-bearing fields deliberately.
  - Keep host-owned secret storage and redacted ordinary reads.
  - Reuse the same stored profile and startup reference model as imports.
  - Make unsupported fields explicit instead of silently ignoring them.
- Non-Goals:
  - Do not add cloud sync, backup export, or cross-device profile sharing.
  - Do not expose raw stored private keys through list/status/diagnostics.
  - Do not implement another VPN engine family.
  - Do not make provider profiles, provider artifacts, or execution plans part
    of the transport profile editor.

## Decisions

### Decision: Structured edit is a host capability

Hosts advertise editable profile-kind schemas separately from import adapters.
The first schema is `wireguard_native_v1`. A shell can render the editor only
when the host says that structured create/update is supported for the required
kind.

This avoids baking a mobile-only WireGuard form into the product without a
contract. It also lets desktop hosts stay fail-closed until they actually own a
profile store.

### Decision: Secret fields are write-only after save

Private keys and any future equivalent secrets may be submitted in a create or
explicit replacement operation, but ordinary reads only return redacted status,
fingerprints, public-key material when safe, and validation results.

For generated keys, the host should generate and store the private key, then
return only safe public-key or fingerprint metadata needed by the operator.

### Decision: Updates are atomic and validation-first

An update must validate the full resulting profile before replacing the
startable material. Invalid edits leave the previous profile and default
bindings intact. Field-level errors may be returned, but messages must not echo
secret values.

### Decision: Import and structured edit converge into one stored model

Importing a `.conf` and saving structured fields both create the same
`wireguard_native_v1` record type. Startup, diagnostics, default binding,
forget, and select-for-startup behavior must not branch on whether the profile
came from a file or from the editor.

### Decision: Runtime-owned endpoint defaults remain explicit

Some execution plans can provide the remote peer endpoint from runtime defaults
or provider artifacts. The editor may store an endpoint when the host supports
it, but startup must still report which endpoint source is used and fail
closed when neither the profile nor runtime defaults provide one.

## Risks / Trade-offs

- Risk: a form UI can encourage storing secrets in Flutter state. Mitigation:
  keep drafts ephemeral, clear secret fields after save, and only persist
  redacted profile status in shell state.
- Risk: editing fields that the materializer ignores creates false confidence.
  Mitigation: host schema advertises supported fields and the host rejects
  unsupported submitted fields.
- Risk: generated private keys need public-key handoff. Mitigation: host-side
  generation returns only the generated public key and redacted fingerprint.
- Risk: current WireGuard parser/model lacks some common fields such as
  persistent keepalive. Mitigation: model field support explicitly and add
  tests proving accepted fields reach the execution lease or are rejected.

## Migration Plan

1. Add structured schema and create/update operations next to the existing
   import/list/validate/select/forget profile-store operations.
2. Normalize imported `.conf` profiles and structured saves through the same
   internal WireGuard profile representation.
3. Add mobile and desktop editor entrypoints from the setup-needed surfaces.
4. Keep `.conf` import as a secondary path and regression-test that startup
   still uses profile refs only.

## Open Questions

- Should host-side private-key generation be the default action, with manual
  private-key entry hidden behind an advanced section?
- Should a generated public key be copyable directly from the editor result,
  or only from redacted profile details?
