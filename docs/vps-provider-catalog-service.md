# VPS Provider Catalog Service

This runbook covers the add-79 VPS-side service and the local `clientd` sync surface.
The service is intentionally bounded: it publishes versioned provider catalog snapshots, issues redacted remote artifacts, records audit events, and exposes bounded metrics. It does not select local VPN profiles and does not run local tunnel adapters.

## Process

Run the VPS catalog process on the operator VPS behind loopback or a private reverse proxy:

```bash
go run ./cmd/vps-provider-catalog \
  -listen 127.0.0.1:7788 \
  -read-token "$VKTP_CATALOG_READ_TOKEN" \
  -issue-token "$VKTP_CATALOG_ISSUE_TOKEN" \
  -admin-token "$VKTP_CATALOG_ADMIN_TOKEN" \
  -issuer vk-turn-proxy-go \
  -audience clientcontrol \
  -endpoint-id vps-main
```

The checked-in smoke catalog currently exposes one managed `generic-turn` source with a `turn-handoff` offer. Production catalog mutation/import remains outside this bounded command until a narrower change adds an admin mutation API.

## VPS HTTP Surface

| Endpoint | Scope | Behavior |
| --- | --- | --- |
| `GET /v1/provider-catalog` | `catalog_read` | Returns the signed snapshot with sources, offers, health, evidence, and redaction policy. |
| `POST /v1/artifacts:issue` | `artifact_issue_export` | Issues an idempotent redacted artifact by `operation_id` after fresh evidence validation. |
| `GET /v1/metrics` | `admin_mutation` | Returns bounded metrics counters for reads, issue attempts, auth, and evidence outcomes. |
| `GET /v1/audit` | `admin_mutation` | Returns audit records with action, scope, status, source/offer ids, reason, and actor. |
| `/v1/admin/` | `admin_mutation` | Reserved; currently returns `not_implemented`. |

Keep `catalog_read`, `artifact_issue_export`, and admin tokens separate. If a deployment deliberately reuses a token, the process grants the union of those scopes to that bearer token.

## Local Clientd Surface

`pkg/clientcontrol` exposes the local side of the same boundary:

```text
GET  /v1/vps-provider-catalogs
POST /v1/vps-provider-catalogs:sync
GET  /v1/provider-sources
POST /v1/vps-provider-catalogs/artifacts:issue
```

The host advertises capability `vps-provider-catalogs` only when endpoint config is supplied. Issued artifacts are stored as `remote_vps_catalog` provider resolutions with `remote_vps` summaries, redacted ordinary reads, and no local secret export.

## Fail-Closed Rules

Catalog sync rejects unsupported schema versions, wrong issuer, wrong audience, wrong endpoint id, unsigned or digest-mismatched snapshots, generation rollback, and expired snapshots.

A transient unavailable endpoint can leave a previously accepted cache visible until its own `expires_at`. Once the cached snapshot expires, local issue calls fail with `vps_provider_catalog_invalid`.

A rollback or other unsafe validation failure clears the source view for that endpoint. Compatibility evaluation also blocks a VPS-issued artifact before startup when its TTL is stale, evidence is missing/stale/degraded, or the artifact is unavailable.

## VPS Smoke

```bash
curl -fsS \
  -H "Authorization: Bearer $VKTP_CATALOG_READ_TOKEN" \
  http://127.0.0.1:7788/v1/provider-catalog | jq '.endpoint_id, .generation'

curl -fsS \
  -H "Authorization: Bearer $VKTP_CATALOG_ISSUE_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"source_id":"managed-turn","offer_id":"turn-handoff","operation_id":"manual-smoke-1","ttl_seconds":30}' \
  http://127.0.0.1:7788/v1/artifacts:issue | jq '.source, .artifact.id, .redaction'

curl -fsS \
  -H "Authorization: Bearer $VKTP_CATALOG_ADMIN_TOKEN" \
  http://127.0.0.1:7788/v1/audit | jq '.[-5:]'
```

Use SSH alias `vk-turn-proxy-go` for remote checks:

```bash
ssh vk-turn-proxy-go 'systemctl --user status vktp-vps-provider-catalog --no-pager'
```

## Systemd Shape

Example user unit:

```ini
[Unit]
Description=vk-turn-proxy-go VPS provider catalog
After=network-online.target

[Service]
EnvironmentFile=%h/.config/vk-turn-proxy-go/vps-provider-catalog.env
WorkingDirectory=%h/vk-turn-proxy-go
ExecStart=%h/vk-turn-proxy-go/bin/vps-provider-catalog -listen 127.0.0.1:7788 -read-token ${VKTP_CATALOG_READ_TOKEN} -issue-token ${VKTP_CATALOG_ISSUE_TOKEN} -admin-token ${VKTP_CATALOG_ADMIN_TOKEN} -issuer vk-turn-proxy-go -audience clientcontrol -endpoint-id vps-main
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
```

If the service is exposed outside loopback, put TLS and request logging in the reverse proxy and keep only the intended `/v1/...` paths reachable.

## Verification

Focused checks:

```bash
go test ./internal/vpscatalog ./pkg/clientcontrol ./cmd/vps-provider-catalog
go build ./cmd/vps-provider-catalog ./cmd/clientd
```

Escalate to `go test ./...` and `go build ./...` when changing shared client-control types, provider artifact mapping, or compatibility evaluation.
