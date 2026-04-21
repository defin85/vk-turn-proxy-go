## Context

The project already exposes server-side runtime behavior through structured
logs, low-cardinality metrics, and stamped build identity. It also already has
repo-owned workflows for building artifacts and running server-oriented remote
scripts against the VPS.

What is missing is a productized server-management surface. Today an operator
must reach for SSH, shell scripts, and manual log inspection even for routine
questions such as:

- which build is currently running on the VPS
- whether the managed server runtime is healthy
- what the recent failure context looks like
- whether a controlled restart or reload succeeded

That gap becomes more painful as more hosted workflows move from developer-only
validation toward routine operation.

## Goals / Non-Goals

- Goals:
  - Provide one authenticated browser surface for managing the supported
    server-side runtime on the VPS.
  - Reuse existing build identity, logs, and metrics as the canonical status
    source instead of creating a shadow observability path.
  - Keep the management path explicit, bounded, and auditable.
  - Make routine inspect/restart/recover workflows possible without SSH-first
    operation.
- Non-Goals:
  - Provide a generic shell-in-the-browser or arbitrary command console.
  - Turn the first slice into a cluster orchestrator, multi-host fleet manager,
    or multi-tenant hosting control plane.
  - Create or manage per-user proxy accounts, share links, quotas, or expiry
    policy as if this were already a 3X-UI-style account panel.
  - Replace repo-owned CI/build scripts as the authoritative packaging path.
  - Redefine the underlying server runtime semantics in this change.

## Decisions

### Decision: The first slice manages one VPS and an allow-listed service set

The first supported management surface should target the project VPS and one
documented set of repo-owned server services. The browser UI should not be a
general host-administration tool.

This keeps the scope narrow enough to verify and keeps the security boundary
clear.

### Decision: Product reference stays close to Render service admin plus Railway audit

The intended operator experience should look more like a bounded service-detail
surface such as Render, with explicit action history and audit semantics closer
to Railway, than like a self-hosted PaaS or generic server-control panel.

That keeps the first slice centered on:
- one managed service or a small allow-listed service set
- explicit build, status, health, logs, and metrics context
- a small audited action set such as start, stop, restart, or reload

It intentionally avoids drifting toward terminal access, generic file editing,
or broad infrastructure management.

### Decision: Browser UI talks only to a VPS-local admin backend

The browser must not shell into the VPS directly and must not own privileged
service actions. Instead, the VPS hosts an explicit admin backend that:

- authenticates the operator
- exposes the documented status and action API
- mediates allowed service-control operations
- records action outcomes for audit and recovery

### Decision: Status reuses build identity plus observability

The admin status model should be derived from supported signals that already
exist or are already explicitly owned by the repository:

- build identity
- lifecycle status
- recent structured logs
- metrics or health summaries

That keeps the web admin aligned with the same truth surfaces used by CLI and
support workflows.

### Decision: Lifecycle actions stay explicit, bounded, and auditable

The first slice should support a small set of documented actions such as:

- start
- stop
- restart
- reload

Each action must report explicit success or failure, and the system must retain
enough audit context to explain who requested the action and what happened.

### Decision: Account or client lifecycle control remains a separate follow-up capability

If the hosted runtime later needs operator-managed proxy accounts, link
issuance, quotas, or expiry controls, that belongs in a separate control-plane
change rather than in this runtime-admin slice.

That keeps `add-41` honest as a VPS runtime-management proposal and prevents
the first authenticated admin surface from expanding into a broader account
panel before the domain model, secret handling, and audit contract are
specified explicitly.

## Risks / Trade-offs

- Risk: service control may require elevated privileges on the VPS.
  Mitigation: keep a narrow allow-list, isolate privileged control in the
  backend boundary, and avoid browser-exposed shell execution.
- Risk: status can drift if it is composed from too many ad-hoc sources.
  Mitigation: require the admin read model to reuse the documented build and
  observability surfaces.
- Risk: operators may expect deployment/update control immediately.
  Mitigation: scope the first slice to runtime management and make broader
  deployment workflows explicit follow-up work.

## Migration Plan

1. Define the supported managed-service model and authenticated web contract.
2. Land read-only service status using build identity, lifecycle state, and
   observability summaries.
3. Add controlled lifecycle actions with explicit audit behavior.
4. Document VPS deployment and recovery around the supported browser path.

## Open Questions

- Which exact server services belong in the initial allow-list beyond the
  primary hosted runtime.
- Whether the first authentication slice uses repo-local credentials,
  reverse-proxy auth, or another VPS-local boundary.
- Whether config editing belongs in the first slice or should remain a
  later, more explicit follow-up change.
