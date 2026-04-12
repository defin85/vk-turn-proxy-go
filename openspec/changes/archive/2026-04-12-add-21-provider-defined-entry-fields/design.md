## Context

`add-20-multi-provider-runtime-families` established that shells discover
provider entry rules from host-reported descriptors and that runtime defaults
stay separate from provider-owned entry data.

That change intentionally stopped at:

- one shipped provider input kind: `link`
- one reusable operator-managed block: runtime defaults
- no provider-defined reusable settings contract

The next likely providers need a small amount of provider-owned configuration
that is still user-editable and reusable across starts of the same saved
profile. Examples include region selection, account mode, device selector, or a
prompt-per-use PIN that must not be persisted.

Without an explicit contract, those needs will reintroduce shell-specific form
logic or abuse runtime defaults with provider-owned meaning.

## Locked Decisions

- Provider-specific entry logic stays in host-reported descriptors, not in
  shell-side provider-name branches.
- Runtime defaults remain a separate product/runtime concern and must not become
  a provider settings escape hatch.
- The shipped add-20 typed input envelope remains in place; this change extends
  descriptor metadata and request/profile payloads instead of undoing add-20.
- Persisted ordinary shell state must continue to avoid secret-bearing provider
  values.

## Goals / Non-Goals

- Goals:
  - let a provider declare reusable user-configurable settings without shell
    hard-coding
  - keep provider settings separate from both runtime defaults and ephemeral
    provider input
  - allow host-side validation from one authoritative provider contract
  - define redaction/persistence rules that stay honest across desktop and
    mobile shells
- Non-Goals:
  - introducing provider-global preferences shared across multiple saved
    profiles
  - introducing persistent secret storage for provider settings
  - replacing the current typed provider input envelope with a fully generic
    schema-driven input system

## Decision: Use a constrained schema-backed settings contract

The descriptor should add an optional `provider_settings_schema` field.

Instead of inventing a fully custom validation language, the schema uses a
constrained object-shaped subset inspired by JSON Schema object validation and
annotation patterns:

- root `type: object`
- `properties`
- `required`
- `additionalProperties: false`
- scalar field types: `string`, `integer`, `number`, `boolean`
- optional `enum`
- optional string and numeric validation keywords:
  `minLength`, `maxLength`, `pattern`, `minimum`, `maximum`
- optional annotations:
  `title`, `description`, `default`, `examples`, `writeOnly`

Repo-specific shell hints are added through explicit extensions rather than by
shell-side provider-name logic:

- `x-vkturn-control`: `text`, `textarea`, `select`, `checkbox`, `password`
- `x-vkturn-persistence`: `profile`, `ephemeral`
- `x-vkturn-order`: root-level field order for rendering

This gives the host one authoritative validation contract while keeping the
shell rendering surface intentionally smaller than full JSON Schema.

### Why not a fully custom `fields[]` descriptor list?

Rejected because it duplicates a validation grammar that already exists in
well-known schema patterns and makes every future validation keyword a bespoke
contract change.

### Why not support arbitrary JSON Schema in shells?

Rejected for the first slice because generic shell rendering for arbitrary
composition keywords would be expensive and ambiguous. The host may validate a
broader schema later, but the portable shell-rendered subset stays explicit and
fail-closed.

## Decision: Separate provider settings from provider input and runtime defaults

Provider settings are not the same thing as:

- the immediate provider input value such as a join link or prompt-only code
- runtime defaults such as local listen address, peer address, DTLS, or log
  level

The control-plane contract should therefore add `provider_settings` as a
separate object in two places:

- `StartResolutionRequest`
- `ProfileSpec`

The resulting shape is:

```json
{
  "provider": "wb-stream",
  "input": {
    "kind": "link",
    "link": "https://example.test/invite/abc"
  },
  "provider_settings": {
    "region": "eu-west",
    "account_mode": "guest",
    "device_pin": "123456"
  }
}
```

This keeps add-20's typed input envelope intact while making provider-owned
settings explicit instead of burying them in ad hoc profile fields.

## Decision: Persistence is field-level and fail-closed

The contract should distinguish between reusable saved-profile values and
prompt-only values.

Field rules:

- `x-vkturn-persistence: profile`
  - may be stored in saved profiles
  - must not be `writeOnly: true` in this slice
- `x-vkturn-persistence: ephemeral`
  - may be supplied for immediate resolution start
  - must not be stored as ordinary saved profile data

Additional rules:

- `writeOnly: true` means the value is prompt-only and must never be persisted
  in ordinary shell state or echoed back through ordinary profile reads/events
- the first slice does not support persistent secret provider settings; if a
  provider needs that later, it should be proposed separately with an explicit
  secure-storage contract
- if a shell sees an unsupported control, type, or persistence hint, it must
  block that provider entry path explicitly rather than guessing a fallback

## Decision: Host validation remains authoritative

The host validates `provider_settings` against the descriptor-declared schema.

Validation rules:

- undeclared keys are rejected
- missing required keys are rejected
- type, enum, pattern, and range violations are rejected
- profile upsert rejects `ephemeral` or `writeOnly` settings in persisted
  profile payloads

Failures should be typed and field-aware. The error contract should identify:

- the failing setting key
- a stable violation code such as `required`, `unknown`, `type`, `enum`,
  `pattern`, `minimum`, `maximum`, or `persistence`

The host must not silently drop bad keys or coerce invalid values into guessed
defaults.

## Decision: Shells render a generic settings section and filter persistence locally

Desktop and mobile shells should add a generic "Provider settings" section near
provider input and before runtime defaults.

Shell behavior:

- render supported fields from `provider_settings_schema`
- keep provider settings separate from runtime defaults in the editor UI
- keep `profile` fields when saving a profile
- keep `ephemeral` fields only in the in-memory draft used for the immediate
  resolution start
- redact `writeOnly` and `ephemeral` values from persisted local shell state,
  similar to the current link redaction rule

This preserves the current model where:

- host profiles own reusable provider-facing data
- local shell state owns only non-secret convenience state
- runtime defaults stay separate and are reused only for same-device execution

## Example Descriptor

```json
{
  "id": "wb-stream",
  "display_name": "WB Stream",
  "input_kind": "link",
  "provider_settings_schema": {
    "type": "object",
    "additionalProperties": false,
    "required": ["region"],
    "x-vkturn-order": ["region", "account_mode", "device_pin"],
    "properties": {
      "region": {
        "type": "string",
        "title": "Region",
        "description": "Choose the control plane region used for link resolution.",
        "enum": ["ru-central", "eu-west"],
        "default": "ru-central",
        "x-vkturn-control": "select",
        "x-vkturn-persistence": "profile"
      },
      "account_mode": {
        "type": "string",
        "title": "Account mode",
        "enum": ["guest", "account"],
        "default": "guest",
        "x-vkturn-control": "select",
        "x-vkturn-persistence": "profile"
      },
      "device_pin": {
        "type": "string",
        "title": "Device PIN",
        "description": "Prompted each time the provider requires a local device unlock.",
        "writeOnly": true,
        "minLength": 4,
        "maxLength": 12,
        "x-vkturn-control": "password",
        "x-vkturn-persistence": "ephemeral"
      }
    }
  }
}
```

## Compatibility and Migration

- Existing providers may omit `provider_settings_schema`; shells then render no
  extra provider settings.
- Existing saved profiles migrate with `provider_settings = {}`.
- Existing `link`-based providers continue to work unchanged.
- No new host capability is required in the first slice because the schema field
  is additive and the shell only sends `provider_settings` when the connected
  host advertises a schema for that provider.

## Risks / Mitigations

- Risk: providers start depending on schema keywords the shells do not support.
  Mitigation: document the supported subset and require fail-closed shell
  behavior for unsupported keywords.
- Risk: provider settings get mixed back into runtime defaults.
  Mitigation: keep separate contract fields and separate UI sections.
- Risk: secret-like values get accidentally persisted locally.
  Mitigation: require `writeOnly` + `ephemeral` for prompt-only values and ban
  persistent secret settings in this slice.
- Risk: host and shell validation drift.
  Mitigation: make host validation authoritative and add compatibility coverage
  around schema validation and persistence filtering.

## Execution Plan

1. Add `provider_settings_schema` to provider descriptors and model types.
2. Add `provider_settings` to profile and resolution-start contracts.
3. Implement host-side validation and field-aware failures.
4. Update desktop/mobile drafts, state stores, and editors to render/filter the
   schema generically.
5. Add control-plane and shell tests for validation, persistence, and redaction.
