## Context

The current mobile provider architecture already separates three layers:

- shipped provider families from the app-owned supported-provider catalog
- saved managed provider records in shell-owned local state
- shipped templates as read-only bootstrap seeds

That architecture is directionally correct, but it still has a missing
operator-owned layer:

- users can save reusable providers
- users can start from shipped templates
- users cannot save their own templates for future provider creation

The current code shape reinforces this gap:

- `MobileShellState` persists `managedProviders`
- `kProviderPresetCatalog` is immutable shipped data
- the `Add provider` chooser already exposes `Families` and `Templates`
- the provider editor already owns the reusable-field surface

This means the repo does not need editable provider families.
It needs a new local template entity and a template lifecycle that reuses the
existing provider-family and provider-settings model honestly.

## Goals

- Add shell-owned user templates for mobile provider bootstrap
- Keep provider families app-owned and non-user-editable
- Keep template contents limited to reusable non-secret provider-owned values
- Preserve snapshot semantics: using a template seeds a new provider draft, and
  later template edits do not mutate earlier drafts, saved providers, or saved
  profiles
- Keep the top-level `Providers` destination provider-list-first instead of
  turning it into a template manager root

## Non-Goals

- Letting operators create, rename, or delete provider families
- Turning shipped templates into editable content
- Introducing remote sync, marketplace behavior, or host-managed template CRUD
- Auto-converting every saved provider into a template
- Letting templates bypass the managed-provider draft flow and mutate Profiles
  directly

## Decisions

### Decision: Introduce a dedicated user-template entity

User templates should be persisted as a separate shell-owned entity rather than
as a flag on `ManagedProviderRecord`.

The proposed model is:

- `ProviderTemplateRecord`
- `ProviderTemplateDraft`

with the same reusable non-secret payload shape as managed providers:

- `id`
- `provider`
- `name`
- `providerSettings`
- `createdAt`
- `updatedAt`

This avoids conflating two different lifecycles:

- managed providers are reusable records that Profiles can apply directly
- templates are bootstrap seeds that create a new managed provider draft

### Decision: Keep families immutable and app-owned

Provider families remain shipped application taxonomy.
The operator may choose a family, but may not create, rename, or delete one.

This keeps provider support explicit and prevents user-defined family names from
drifting away from the actual supported provider/runtime contract.

### Decision: Use snapshot seeding, not live template binding

Selecting a user or shipped template should seed a new managed provider draft.
After that seed step:

- the new provider draft is independent
- saving the provider creates or updates a managed provider record
- later template edits do not mutate saved providers or saved profiles

This mirrors the current snapshot semantics already used by managed providers.

### Decision: Reuse the provider field editor with a template mode

The field surface for a user template is almost the same as for a managed
provider:

- chosen provider family
- operator-visible name
- reusable non-secret provider settings

The implementation should therefore reuse the existing provider editor panel
and add a template editing mode, with mode-specific copy and actions such as:

- `Save template`
- `Delete template`
- `Use template`
- `Save as template`

This reduces UI drift and keeps zero-reusable-fields behavior consistent across
providers and templates.

### Decision: Separate `My templates` from shipped templates in the chooser

The existing `Templates` chooser surface should evolve into two explicit
template groups:

- `My templates`
- `Shipped templates`

Search and filtering can still work across both groups, but the distinction
must remain visible because the allowed actions differ:

- user templates can be edited or deleted
- shipped templates are read-only seeds

### Decision: Create templates from provider work, not from families alone

The primary creation path for a user template should begin from a provider
draft or saved provider record via `Save as template`.

That gives the operator a concrete, already-normalized provider-family context
and avoids a second independent blank-template wizard that would duplicate the
provider editor unnecessarily.

Editing an existing user template should open the same template editor mode
prefilled from that template.

## Risks / Trade-offs

- The template and managed-provider payload shapes are similar, so duplicated
  model code could drift. The implementation should centralize shared
  normalization helpers even if the entities stay distinct.
- A crowded chooser can become noisy once user templates and shipped templates
  both grow. Search/filtering should stay available, but not erase the visual
  distinction between the two sources.
- If the UI copy is weak, operators may not understand the difference between
  `Save provider` and `Save as template`. The template flow needs explicit
  bootstrap language.

## Migration Plan

- Extend persisted mobile shell state with an optional `provider_templates`
  collection.
- Default older state blobs to an empty template list when the field is absent.
- Do not auto-migrate existing managed providers into templates.

## Validation Plan

- `openspec validate add-35-mobile-user-provider-templates --strict --no-interactive`
- `cd mobile/gui_shell && flutter analyze`
- `cd mobile/gui_shell && flutter test test/widget_test.dart`
- widget coverage for:
  - `Save as template` from a provider draft or record
  - user template use, edit, and delete
  - shipped-template read-only behavior
  - provider families remaining non-editable
- manual mobile validation of the template chooser and template editor on a
  compact and a wide layout
