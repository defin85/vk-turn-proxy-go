## 1. Contract and models
- [x] 1.1 Define the `vps-provider-catalog-and-artifact-service` DTOs for
      catalog snapshots, provider sources, artifact offers, access methods,
      freshness, issuer identity, evidence, and redaction metadata.
- [x] 1.2 Define artifact issue/export request and response DTOs with TTL,
      provenance, authorization, audit context, and explicit redaction rules.
- [x] 1.3 Define validation rules for stale, invalid, unsigned, degraded, or
      missing-evidence catalog snapshots.
- [x] 1.4 Define issuer, audience, endpoint identity, monotonic generation, and
      anti-rollback validation rules for synced snapshots.
- [x] 1.5 Define separate authorization scopes for catalog read, artifact
      issue/export, and admin mutation paths.
- [x] 1.6 Define idempotency or operation-identity semantics for mutating
      issue/export, delivery-material regeneration, and account-backed artifact
      actions.

## 2. VPS service boundary
- [x] 2.1 Add a bounded VPS service entrypoint such as
      `cmd/vps-provider-catalog` backed by `internal/vpscatalog`.
- [x] 2.2 Implement read-only catalog endpoints and explicit artifact
      issue/export endpoints without arbitrary shell access or raw config
      editing.
- [x] 2.3 Enforce deny-by-default authorization on read, issue/export, and admin
      mutation paths, with separate credentials or scopes.
- [x] 2.4 Add source health and evidence collection for the first managed
      Generic TURN and WireGuard-native remote ingress path.
- [x] 2.5 Add structured audit records for catalog mutations, artifact
      issuance, delivery-material regeneration, and denied requests.

## 3. Local control-plane integration
- [x] 3.1 Add remote catalog source configuration, sync, cache, and validation
      to the local control-plane host.
- [x] 3.2 Map valid remote catalog entries into provider-source descriptors and
      provider-runtime artifact references without local VPN profile defaults.
- [x] 3.3 Map explicit remote artifact issue/export results into the
      provider-resolution-handoff model with expiry and provenance.
- [x] 3.4 Feed remote source/artifact facts into the `add-78` compatibility
      evaluator and startup revalidation without implicit provider or VPN
      profile substitution.
- [x] 3.5 Persist only non-secret catalog cache metadata needed for freshness,
      issuer/audience validation, generation tracking, and diagnostics.

## 4. Operations and observability
- [x] 4.1 Document the supported VPS deployment, systemd unit, firewall and
      reverse-proxy expectations, recovery flow, and `vk-turn-proxy-go` SSH
      alias checks.
- [x] 4.2 Add structured events and low-cardinality metrics for catalog sync,
      artifact issuance, evidence freshness, degraded status, and startup
      rejection caused by remote catalog facts.
- [x] 4.3 Add operator diagnostics that show catalog generation, freshness,
      source status, and recent artifact issuance failures without secrets.

## 5. Verification
- [x] 5.1 Add unit tests for catalog snapshot validation, stale/invalid,
      wrong-audience, rollback, missing-evidence rejection, redaction, and
      artifact issue/export TTL handling.
- [x] 5.2 Add HTTP handler tests for catalog reads, artifact issue/export,
      read-scope denial of privileged actions, idempotent retry handling,
      degraded evidence, and audit emission.
- [x] 5.3 Add `pkg/clientcontrol` tests for sync/cache behavior, stale cached
      snapshot handling, remote artifact mapping, and no implicit VPN profile
      selection.
- [x] 5.4 Add compatibility-evaluator tests covering a valid remote
      `generic_turn` source with `wireguard_native_v1`, missing profile, stale
      remote artifact, degraded source, and missing evidence.
- [x] 5.5 Add a repo-owned smoke or harness path for the first managed VPS
      catalog entry without depending on manual SSH inspection as acceptance
      evidence.
- [x] 5.6 Run `go test ./internal/vpscatalog ./pkg/clientcontrol` and the
      smallest affected runtime/evaluator package tests.
- [x] 5.7 Run `openspec validate add-79-vps-provider-catalog-and-artifact-service --strict --no-interactive`.
- [x] 5.8 Run `openspec validate --all --strict --no-interactive`.
- [x] 5.9 Run `git diff --check`.

## 6. Finish-to-100 residual closure
- [x] 6.1 Refresh the first managed VPS catalog snapshot, generation, health, and
      evidence on catalog read and artifact issue so the default VPS service does
      not become stale merely from process uptime.
- [x] 6.2 Persist non-secret remote catalog cache metadata and highest accepted
      generation for configured host cache paths, preserving rollback detection
      across host restarts.
- [x] 6.3 Propagate explicit `export_secret=true` VPS export payloads through the
      managed resolution export action while keeping ordinary reads, events, and
      diagnostics redacted.
- [x] 6.4 Accept newer monotonic artifact issue generations for the same
      endpoint/source/offer while rejecting generations below the cached snapshot.
