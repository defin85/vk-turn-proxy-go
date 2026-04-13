## Context

The current shell workflow combines three ideas in a way that does not match
the intended operator mental model:

- host descriptors are treated as the primary visible provider list
- `Provider configs` are the only reusable provider-focused records
- presets act like a second provider taxonomy, including not-yet-shipped
  families

That model is honest for descriptor-driven validation, but it is poor as the
main operator-facing information architecture:

- a shipped provider disappears from the reusable-provider surface if it does
  not advertise a reusable settings schema
- the app has no single source of truth for "providers we support"
- presets overreach into future provider families instead of staying a seed
  mechanism for supported provider records

The desired model is:

- one app-owned catalog of supported providers
- managed provider records created from that catalog and editable in shell
  state
- presets as seed variations for new managed provider records
- profiles choosing either a managed provider record or a custom path
- host descriptors still providing runtime constraints and fail-closed
  validation

## Goals / Non-Goals

- Goals:
  - give desktop and mobile one shared operator-facing provider catalog
  - make supported providers visible even when the current host does not expose
    reusable provider settings
  - keep presets subordinate to the supported-provider catalog
  - let profile workflows choose a managed provider or a custom provider path
  - keep runtime materialization snapshot-based and explicit
- Non-Goals:
  - add new provider adapters in this change
  - introduce host-side indirection where sessions depend on a managed-provider
    identifier
  - silently keep speculative provider families visible as if they were
    supported
  - preserve the current `Provider configs` surface as the primary operator
    workflow

## Decisions

### Decision: Shared shell core owns the supported-provider catalog

`packages/flutter_shell_core` should define the operator-facing catalog of
providers that the application intentionally supports.

Each supported-provider definition should include:

- stable provider id
- display title and explanatory copy
- operator-facing affordance metadata
- optional app-owned seed defaults
- rules for whether custom editing is allowed

Why shared shell core:

- desktop and mobile need the same provider taxonomy
- this is application UX truth, not host runtime truth
- it removes the current split between provider descriptors and preset cards

### Decision: Host descriptors become a runtime overlay, not the primary catalog

The control plane should continue to advertise provider descriptors for runtime
constraints, browser policy, settings validation, and availability.

The shells should layer those descriptors onto the app-owned provider catalog:

- a supported provider can stay visible even if the current host cannot run it
- the UI can show explicit unavailable state instead of making the provider
  disappear
- descriptor-defined settings still remain the validation source of truth when
  the host advertises them

### Decision: Managed provider records replace provider-config CRUD as the primary shell workflow

The shell-primary reusable record should be a managed provider record, not a
host-owned `provider_config`.

Each managed provider record is:

- scoped to one supported provider family
- stored in shell-owned persisted state
- allowed to carry only reusable non-secret provider-owned parameters and
  presentation metadata
- applied into profile drafts by snapshot copy, never by hidden live reference

This keeps the operator's reusable provider inventory in one place and avoids
the current mismatch where only schema-rich providers can exist in the
provider-focused surface.

Some supported providers may legitimately have zero reusable provider-owned
parameters in the first slice. That is still preferable to smuggling
session-scoped links, static secrets, or runtime defaults into the managed
provider catalog.

This explicitly allows the first shipped catalog to include providers such as
`vk` and `generic-turn` even if their reusable managed-provider field surface
is empty or nearly empty.

### Decision: Presets seed managed provider records

Presets should not be a second list of providers.

Instead, each preset must:

- target one supported provider family
- seed a new managed provider draft or record
- stay within that provider family's supported parameter space

This means:

- no preset may exist for a provider that is not in the app-owned supported
  catalog
- presets for future provider families stay out of the shipped UX until those
  providers are intentionally supported

### Decision: Profiles choose managed-provider or custom mode but materialize to snapshots

The profile editor should offer two explicit paths:

- managed provider: choose an existing provider record from the app-owned
  catalog-backed inventory
- custom provider: type a raw provider id and raw provider input without
  mutating the managed-provider inventory

Boundary rules:

- runtime defaults stay with the profile draft
- prompt-only or secret provider inputs stay in custom/profile-local flows
- managed provider records do not persist invite/session links or static TURN
  credentials in this change

The saved profile and immediate start request should continue to materialize to
ordinary `provider`, `link`, and `provider_settings` values before they reach
the control plane.

Why:

- the host stays agnostic to shell-local provider-record identity
- sessions and saved profiles remain inspectable without extra indirection
- rollback and migration remain simpler than a host-resolved provider-record id

The shell should persist enough local presentation metadata to reopen a saved
profile in managed-provider mode when that profile was originally created from
or last associated with a managed provider. That metadata is shell-owned UX
state, not a control-plane contract field.

### Decision: Existing provider-config state migrates forward, not sideways

The existing local shell state may already contain `provider_configs`.

Migration should:

- import compatible existing provider-config records into managed provider
  records when provider family mapping is clear
- keep the migrated profile workflow snapshot-based
- stop using host-side provider-config CRUD in ordinary desktop/mobile flows

This avoids freezing old state in place while still converging on the intended
model.

## Risks / Trade-offs

- Risk: app-owned provider catalog drifts from host capabilities.
  Mitigation: keep host descriptors as a runtime overlay and always show
  explicit unavailable state when the current host cannot run a supported
  provider.
- Risk: removing speculative preset entries may feel like a visible UX step
  back.
  Mitigation: only show providers and presets the application intentionally
  supports; add future families back when they are real.
- Risk: migration from persisted `provider_configs` could be lossy.
  Mitigation: migrate only clean one-to-one cases and keep explicit fallback
  messaging when a record cannot be upgraded automatically.
- Risk: shells and host may temporarily diverge during rollout.
  Mitigation: keep the control-plane contract snapshot-based and backward-safe
  while shell state ownership changes.

## Migration Plan

1. Add shared shell-core supported-provider and preset models.
2. Add shell-owned managed-provider record persistence and migration from old
   provider-config state.
3. Rework desktop and mobile provider workspaces around managed providers.
4. Drop shell capability negotiation dependence on host-managed
   `provider_configs` while keeping backward-compatible reads optional.
5. Update profile editors to choose managed-provider or custom mode.
6. Validate with controller, UI, compatibility, and migration coverage before archiving the
   change.
