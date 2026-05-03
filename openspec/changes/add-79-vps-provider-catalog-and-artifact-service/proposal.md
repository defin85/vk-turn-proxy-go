# Change: [79] Add VPS provider catalog and artifact service

## Why

`add-77` separates provider or contour sources from VPN transport profiles, and
`add-78` adds the local control-plane evaluator that combines those axes. The
missing server-side slice is the project VPS service that publishes remote
provider sources, artifact offers, freshness, and evidence without requiring
each desktop or mobile host to discover those facts through SSH, static files,
or Flutter-side heuristics.

This change makes the VPS at the canonical `vk-turn-proxy-go` deployment
boundary a first-class source of provider catalog and artifact references while
keeping local VPN transport profile selection and compatibility evaluation in
the client host.

## Sequence

- Order: `79`
- Depends on: `add-77-independent-provider-and-transport-selection`,
  `add-78-provider-transport-compatibility-control-plane`, existing
  provider-runtime artifact and resolution-handoff contracts
- Relates to: `add-41-flow-2-vps-admin-server-admin-web`,
  `add-45-flow-2-vps-admin-proxy-account-admin`, and the documented
  WireGuard-native remote ingress runbooks
- Unblocks: remote provider-source catalog delivery, VPS-issued artifact
  references, and health/evidence-backed compatibility decisions in the local
  control plane

## What Changes

- Add a VPS-hosted provider catalog and artifact service capability with
  versioned catalog snapshots, source descriptors, artifact offers, compatible
  access-method hints, freshness windows, and health/evidence metadata.
- Define explicit artifact issuance/export endpoints for short-lived remote
  artifacts such as managed TURN handoffs, future SFU/WebRTC attach material,
  camera-stream access, or proxy-account delivery references.
- Keep ordinary catalog reads redacted and reference-based; raw provider
  secrets or delivery material require explicit issue/export actions with TTL,
  authorization, and audit context.
- Require local `clientd` and embedded hosts to import remote catalog snapshots
  as provider/source facts, then pass those facts into `add-78` compatibility
  evaluation instead of computing startability from display labels.
- Treat stale, unsigned, invalid, degraded, or missing-evidence remote catalog
  data as non-startable unless the operator explicitly chooses a documented
  fallback source.
- Keep local VPN transport profiles, profile secrets, and host-native adapter
  readiness out of the VPS catalog service.

## Impact

- Affected specs: `vps-provider-catalog-and-artifact-service` (new),
  `client-control-plane`, `provider-runtime-artifacts`,
  `provider-resolution-handoff`, `runtime-execution-planning`,
  `runtime-observability`
- Affected code: future `cmd/vps-provider-catalog`, `internal/vpscatalog`,
  remote catalog client/cache code in `pkg/clientcontrol`, provider-runtime
  artifact adapters, compatibility-evaluator inputs, VPS deployment/runbook
  docs, and Go tests

## Assumptions

- The first deployment targets the project VPS reachable through the canonical
  `vk-turn-proxy-go` SSH alias; API clients must not hard-code the current
  public IP as the logical service identity.
- The service can initially publish managed Generic TURN and WireGuard-native
  remote ingress facts before broader WB TURN, Telemost, SFU, Rostelecom,
  V2Ray, SOCKS5, Hysteria, or QUIC-derived families are implemented.
- VPS catalog health and evidence can inform compatibility status, but final
  startup readiness still belongs to local `add-78` revalidation plus native
  host evidence.
