## Context

The current shell model has two useful invariants:

- provider-specific entry fields come from host-reported descriptors
- runtime defaults remain separate from provider-owned settings

That model still leaves one workflow gap:

- reusable provider settings are trapped inside one saved profile
- there is no provider-focused CRUD surface separate from runtime profile
  editing
- there is no fast, curated bootstrap into the most important provider
  families

`add-21-provider-defined-entry-fields` explicitly avoided provider-global
preferences shared across profiles. This change intentionally re-opens that
scope, but only for non-secret descriptor-retained provider settings.

## Goals / Non-Goals

- Goals:
  - let operators create, edit, and delete reusable provider configs without
    touching runtime defaults
  - keep provider config validation descriptor-driven and fail-closed
  - provide one shared preset bootstrap catalog for desktop and mobile
  - keep saved profiles explicit and auditable instead of mutating behind a
    hidden shared reference
- Non-Goals:
  - implement `wb-stream` or `smarthome` provider adapters in this change
  - introduce persistent secret provider settings
  - make saved profiles live-reference mutable provider configs
  - invent provider-name-specific form fields in shell code

## Decision: Provider configs are first-class host resources

The local control plane should expose a reusable provider-config library.

Each provider config record is:

- scoped to exactly one provider id
- validated against that provider's `provider_settings_schema`
- limited to descriptor-retained, non-secret settings
- named so the operator can distinguish multiple reusable variants for one
  provider

Suggested shape:

```json
{
  "id": "cfg-01",
  "provider": "wb-stream",
  "name": "WB EU guest",
  "provider_settings": {
    "region": "eu-west",
    "account_mode": "guest"
  },
  "created_at": "2026-04-13T10:15:00Z",
  "updated_at": "2026-04-13T10:16:00Z"
}
```

Why host-side instead of shell-local only:

- the same control-plane validation can reject undeclared or now-invalid fields
- desktop and mobile share one contract instead of diverging local libraries
- provider configs stay next to the provider catalog they depend on

## Decision: Saved profiles stay snapshot-based

This change should not make a saved profile silently depend on a mutable
provider-config record.

Flow:

1. operator chooses a provider config or preset
2. shell copies the retained provider settings into the active draft
3. save/start/resolve uses the draft/profile snapshot

Why not a live reference:

- editing one provider config should not silently mutate existing saved
  profiles
- profile behavior remains inspectable from the profile record alone
- rollback is simpler because there is no hidden fan-out from one config edit

The UI may still remember which provider config last seeded the draft, but that
is presentation metadata, not runtime indirection.

## Decision: Presets are shared shell bootstrap assets

Preset cards should live in shared Flutter code, not as proof of host
capability.

Initial preset catalog:

- `vk-default`
- `wb-stream-default`
- `smarthome-default`

Each preset declares:

- stable preset id
- target provider id
- display title and explanatory copy
- suggested profile name
- optional seed provider settings
- optional shell hints such as icon or emphasis tone

Why not host-advertised presets in the first slice:

- `wb-stream` and `smarthome` adapters are not shipped yet
- host-advertised presets would either lie about current provider availability
  or force partial fake descriptors into the runtime contract
- shell-owned presets can still stay honest by showing disabled/unavailable
  state when the connected host does not advertise the provider descriptor

## Decision: Preset availability is descriptor-gated and fail-closed

The shell must not let a preset bootstrap into an unsupported provider flow.

Rules:

- if the connected host advertises the matching provider descriptor and the
  schema subset is supported, the preset is actionable
- if the descriptor is missing, the preset stays visible but unavailable with
  explicit copy
- if the descriptor exists but its provider-settings schema is unsupported, the
  preset may still open a draft shell, but provider-config save/apply actions
  remain blocked with the same fail-closed messaging used elsewhere

## Decision: Provider config editing reuses the existing schema-driven renderer

The provider-config editor is not a second provider-form system.

It should reuse the same descriptor-driven field renderer already used inside
profile editors, but with a narrower scope:

- include provider settings only
- exclude provider input/link
- exclude runtime defaults
- exclude session or resolution actions

This keeps provider-specific meaning in descriptors and avoids duplicating
validation logic in a second UI surface.

## Decision: Desktop and mobile expose the same IA concepts with platform-fit layout

Shared concepts:

- `Presets`
- `Provider configs`
- `Profiles`

Desktop:

- left rail or library column with distinct preset/config/profile sections
- central workspace switches between provider-config editor and profile editor
- profile editor includes an explicit "Apply provider config" affordance

Mobile:

- workflow-first navigation keeps one primary entry surface
- `Presets` and `Provider configs` become explicit destinations, sheets, or
  segmented sub-surfaces rather than one long stacked form
- provider-config CRUD uses full-screen or sheet-based editing with the same
  descriptor renderer

## Decision: Provider configs remain non-secret and descriptor-retained only

The host must reject:

- `writeOnly` settings
- `ephemeral` settings
- undeclared setting keys
- settings for providers the host does not currently advertise

If a stored provider config becomes invalid because the descriptor changed or
the provider disappeared, the shells should show it as unavailable/incompatible
until the operator edits or deletes it.

## Risks / Trade-offs

- Risk: operators expect provider-config edits to automatically update existing
  saved profiles.
  Mitigation: keep the model snapshot-based and label apply behavior clearly in
  the UI.
- Risk: shell-owned presets drift from the host-reported provider catalog.
  Mitigation: key presets by stable provider id and gate every preset against
  descriptor availability before enabling it.
- Risk: provider configs reintroduce provider-global secret storage.
  Mitigation: reject `writeOnly` and `ephemeral` settings from provider-config
  CRUD entirely.
- Risk: desktop and mobile diverge into different provider-config behaviors.
  Mitigation: keep the record model and renderer shared in
  `flutter_shell_core`; vary only layout and affordance density.

## Migration Plan

1. Add provider-config CRUD to the local control plane with descriptor-based
   validation.
2. Extend shared shell models/controllers to read and apply provider configs.
3. Add the shared preset catalog in `flutter_shell_core`.
4. Rework desktop UI around preset/config/profile entry points.
5. Rework mobile UI around the same concepts with mobile-fit navigation.
6. Add host + shell tests for invalid config rejection, unavailable presets,
   and snapshot-based apply flows.
