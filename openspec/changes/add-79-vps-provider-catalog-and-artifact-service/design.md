## Context

RelayDock now has three separate concepts that should stay separate:

- provider or contour source selection (`add-77`)
- local VPN transport profile selection (`add-77` and the profile store)
- local provider/transport compatibility evaluation (`add-78`)

The project VPS is the missing upstream for remote provider/source facts. It
already hosts repo-owned tunnel services, remote ingress ports, and operator
runbooks, and separate OpenSpec changes plan VPS runtime admin (`add-41`) and
proxy account admin (`add-45`). None of those changes define a client-facing
provider catalog service that desktop/mobile hosts can sync.

Without this change, every client host would either ship a stale static catalog
or encode VPS-specific provider availability in shell code. Both options would
undermine the fail-closed model and make degraded remote state invisible to the
compatibility evaluator.

## Goals

- Provide a VPS-hosted, versioned provider catalog snapshot that local hosts can
  sync and validate.
- Publish remote provider source descriptors, artifact offers, access-method
  hints, health, evidence, and freshness without leaking secrets.
- Provide explicit artifact issue/export APIs for short-lived remote artifacts.
- Feed local `add-78` compatibility evaluation with remote source and artifact
  references instead of display-only provider names.
- Keep operator writes, account mutations, and delivery-material regeneration
  behind an authenticated, audited VPS boundary.
- Keep local VPN transport profiles and native adapter readiness local.

## Non-Goals

- Implement a full multi-tenant provider marketplace or billing system.
- Replace `add-41` runtime-service admin or `add-45` proxy-account admin.
- Add new provider engines such as WB TURN, Telemost, SFU, Rostelecom,
  V2Ray, SOCKS5, Hysteria, or QUIC in this slice.
- Make the VPS choose a local VPN transport profile for a client.
- Let desktop/mobile shells infer compatibility from remote catalog display
  metadata.
- Expose arbitrary VPS shell commands, raw config editing, or unrelated host
  services.

## Decisions

### Decision: The VPS publishes source facts, not local startability

The catalog service may say that a source can issue a `generic_turn` artifact,
that a remote ingress supports `turn_datagram`, or that a source has degraded
health. It must not say that a user's current device is startable with a
particular local VPN profile. Local startability remains the responsibility of
the `add-78` evaluator and startup revalidation.

### Decision: Catalog snapshots are versioned and freshness-bound

Each client-facing catalog read should carry a schema version, generation or
revision, issuer identity, `generated_at`, `expires_at` or max-age semantics,
and enough integrity metadata for the local host to reject stale or invalid
snapshots. Cached snapshots may remain inspectable, but stale or unverifiable
catalog data must not become startable input.

The local host should also track the highest accepted generation per issuer and
audience. A previously valid but older snapshot is a rollback candidate and must
not become startable input unless the operator performs an explicit documented
trust reset or the issuer uses a documented epoch rollover.

### Decision: Ordinary reads are redacted and reference-based

Catalog entries and ordinary artifact reads should expose stable IDs, artifact
families, access methods, source health, and compatibility hints. Raw TURN
credentials, room tokens, proxy account links, cookies, camera tokens, and QR or
config exports require explicit issue/export actions with TTL and audit
context.

### Decision: Artifact issuance is an explicit remote action

Resolving or issuing a remote artifact should create a typed artifact reference
with expiry and provenance. Local hosts then map that reference into the
provider-resolution-handoff model and pass it to compatibility evaluation.
The service must not silently create accounts, rotate delivery material, or
persist long-lived client secrets as a side effect of listing the catalog.

Mutating issue, export, regeneration, or account-backed delivery actions need a
caller-supplied operation identity or equivalent idempotency key so a network
retry cannot accidentally create duplicate accounts, rotate secrets twice, or
produce two unrelated delivery artifacts for one operator action.

### Decision: Client and admin authority are separate

Catalog reads, artifact issue/export actions, and catalog or account mutations
must have separate authorization scopes. A read-only client credential may sync
catalog facts, but it must not mutate source policy or regenerate delivery
material. Admin credentials may mutate only through the documented admin
boundary and still must not bypass ordinary redaction, audit, freshness, or
idempotency rules.

### Decision: Admin integration is bounded

`add-41` can later show service health for the catalog service, and `add-45`
can later contribute account or delivery material through explicit APIs. This
change still owns the client-facing catalog/artifact contract and must remain
valid even if those admin surfaces ship in separate increments.

### Decision: Evidence is first-class but scoped

The service should expose health and evidence fields such as source status,
last probe time, remote ingress identity, degraded reason, and limit-domain or
throughput-ceiling hints when they are known. Those fields are inputs to local
diagnostics and compatibility status, not guarantees of client-side data-plane
readiness.

## Risks / Trade-offs

- Risk: remote catalog data can become stale while clients are offline.
  Mitigation: require freshness windows and make stale cached data inspectable
  but non-startable.
- Risk: catalog entries may accidentally leak secret-bearing delivery material.
  Mitigation: keep ordinary reads redacted and require explicit issue/export
  actions with audit and TTL.
- Risk: the VPS service can overfit the first Generic TURN/WireGuard path.
  Mitigation: model sources, artifact families, access methods, and evidence as
  typed fields rather than provider-name-specific switches.
- Risk: local and VPS compatibility logic can diverge.
  Mitigation: the VPS publishes facts and hints only; the local control plane
  remains the single compatibility evaluator.

## Migration Plan

1. Define the catalog snapshot, source descriptor, artifact offer, evidence,
   and artifact issue/export DTOs.
2. Implement a VPS-local service boundary for read-only catalog sync and
   explicit artifact issuance.
3. Add local host sync/cache/validation logic and map remote artifacts into the
   existing provider-runtime artifact and resolution-handoff surfaces.
4. Wire remote source/artifact facts into the `add-78` compatibility evaluator.
5. Add VPS deployment docs, observability, audit, and a first Generic
   TURN/WireGuard-native remote ingress smoke path.

## Open Questions

- Which authentication mechanism is first for client-facing catalog reads:
  signed public snapshots, per-install read tokens, reverse-proxy auth, or a
  combination. The scope split between read, issue/export, and admin mutation is
  not open.
- Whether artifact issuance for the first slice should be stateless
  short-lived tokens only or include an audited server-side artifact store.
- Which remote health probes are mandatory for the first supported catalog
  entry beyond process health, ingress bind status, and recent synthetic probe
  evidence.
