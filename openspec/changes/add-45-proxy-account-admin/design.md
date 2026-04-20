## Context

`add-41-vps-server-admin-web` scopes the first authenticated browser admin
surface to runtime status and service lifecycle on one VPS. That keeps routine
health inspection and restart or recovery flows off SSH, but it still leaves a
different problem unsolved: how an operator safely manages proxy accounts when
the hosted runtime needs more than one static hand-maintained configuration.

Panels such as 3X-UI are relevant here because they expose the right domain
shape: profiles or inbounds, client accounts, connection links, QR codes,
traffic limits, and expiry controls. But they are not the right security or
deployment model to copy directly. This change therefore treats 3X-UI as an
information-architecture reference only, while keeping the project's own
authenticated VPS-local backend boundary, audit expectations, and fail-closed
behavior explicit.

## Goals / Non-Goals

- Goals:
  - Provide one authenticated browser surface for managing supported proxy
    profiles and client accounts on the project VPS.
  - Keep account mutations behind an explicit VPS-local admin backend instead
    of raw file edits or browser-driven shell commands.
  - Support explicit operator workflows for create, update, disable, revoke,
    and delivery-material regeneration.
  - Define redaction and audit rules for connection material such as links,
    QR codes, or config exports.
- Non-Goals:
  - Replace the runtime-admin status and service-lifecycle scope of `add-41`.
  - Provide a generic config editor, terminal, or host-administration panel.
  - Turn the first slice into billing, subscription management, or tenant
    self-service.
  - Manage multiple hosts or a fleet-wide orchestrator in the first slice.

## Decisions

### Decision: Keep runtime admin and account admin as separate capabilities

Runtime health and service lifecycle belong to `add-41-vps-server-admin-web`.
Proxy profile and client-account lifecycle belong here.

That split keeps the first authenticated service-admin surface honest and
avoids mixing runtime diagnostics with secret-bearing account mutations in one
underspecified change.

### Decision: The first slice targets one VPS and an allow-listed proxy account model

The initial capability should manage one documented VPS and one allow-listed
set of proxy profiles or inbounds plus their client accounts.

This keeps the domain narrow enough to validate before talking about broader
provider families, tenant hierarchies, or fleet-level management.

### Decision: Browser mutations go only through a VPS-local admin backend

The browser must not edit runtime config files directly and must not shell into
the VPS to create or revoke accounts.

Instead, a VPS-local admin backend should:
- authenticate the operator
- expose documented read and mutation APIs
- mediate writes into the managed proxy runtime or its account store
- report explicit success or failure
- retain audit context for follow-up

### Decision: 3X-UI is an information-architecture reference, not a production blueprint

3X-UI is useful as a reference for the operator-facing object model:
- profile or inbound list
- client or account list
- connection material such as link or QR
- limits, expiry, and enabled-state

But this project should not inherit 3X-UI's production posture or assume its
security model is acceptable by default. The repository still owns its own
authentication, redaction, audit, and deployment contract.

### Decision: Delivery material needs explicit redaction and regeneration rules

Account panels inevitably surface connection artifacts that may contain raw
secrets. The first slice must therefore define:
- when connection material is visible
- what is redacted by default
- when regeneration invalidates prior material
- which actions are recorded for audit

That keeps the product from quietly treating secret-bearing delivery artifacts
as harmless status text.

## Risks / Trade-offs

- Risk: the account model can overfit one proxy runtime and block future reuse.
  Mitigation: keep the first slice allow-listed and explicit about which
  profile and account semantics are authoritative.
- Risk: connection artifacts can leak secrets through logs, screenshots, or
  permissive UI defaults.
  Mitigation: define redaction, regeneration, and audit behavior up front.
- Risk: operators may expect billing, self-service, or bulk multi-tenant
  workflows immediately.
  Mitigation: keep those concerns explicitly out of scope and validate only the
  operator-managed first slice.

## Migration Plan

1. Define the managed proxy profile and client-account model.
2. Land read-only account status, limits, expiry, and delivery-material views.
3. Add explicit account lifecycle mutations with audit behavior.
4. Document the supported operator workflow for create, rotate, revoke, and
   recovery.

## Open Questions

- Which concrete proxy runtime family is first in scope for managed accounts.
- Whether the first slice should expose URI links only or also QR and config
  download artifacts.
- Whether quota or traffic usage comes from runtime-native counters,
  repository-owned telemetry, or a later dedicated accounting surface.
