## Context

The mobile shell recently promoted `Providers` into the main navigation, but
the actual surface still behaves like an overloaded workspace:

- the root page shows presets
- the root page shows the saved provider list
- the root page embeds the full provider editor

That works for a tiny catalog, but it does not scale once more templates or
provider families appear.
It also breaks parity with `Profiles`, whose product contract is much clearer:
open the destination, see the list, then drill into detail.

The checked-in architecture itself is still sound:

- `ManagedProviderRecord` is the user-owned reusable provider entity
- the app-owned provider catalog is a shell-owned taxonomy of supported
  provider families
- presets are bootstrap seeds, not separate provider identities
- host descriptors only overlay current availability and reusable-field support

The redesign therefore should not replace the underlying model.
It should expose that model more honestly.

## Goals

- Make saved provider records the primary entity of the top-level `Providers`
  destination
- Keep bootstrap templates easy to discover without letting them dominate the
  root page
- Remove internal implementation language from operator-facing UI
- Support both phone drill-down and wider list-detail presentation
- Preserve explicit availability overlays and unsupported-template honesty

## Non-Goals

- Replacing the shell-owned provider workspace with host-managed CRUD
- Turning provider templates into a remote marketplace or live catalog sync
- Designing arbitrary nested provider taxonomies beyond the current family and
  template concepts
- Changing how profile drafts snapshot managed provider values

## Decisions

### Decision: Make saved providers the root-level object

The top-level `Providers` destination should center on saved managed provider
records.
On open, the operator should immediately see:

- saved providers
- search or filtering when needed
- one clear primary create action

The root page should not render the template gallery and the full editor as
peer sections before the operator has chosen a task.

### Decision: Move templates into the create flow

Provider presets should remain available, but as an explicit create path such
as:

- `New provider`
- choose `Start from template` or `Blank provider`
- if template, open a template picker
- if blank, choose the provider family directly

This keeps presets discoverable while preventing a large template catalog from
crowding the main list surface.

### Decision: Treat `app-owned provider catalog` as an internal term

The current concept is architecturally correct but wrong for product copy.
The operator should mostly see:

- `Provider family`
- `Supported provider families`
- `Template`

The phrase `App-owned provider catalog` should stay in specs and internal code
discussions, not as the main title or explanatory label of the editor surface.

### Decision: Use adaptive list-detail instead of one overloaded page

On phone-sized layouts:

- root `Providers` shows the saved-provider list
- editor/detail opens as the next surface or explicit drill-down
- template browsing is a separate sheet or page in the create flow

On wider mobile layouts:

- the saved-provider list remains the navigation spine
- selected detail or editor may appear beside that list

This keeps the same mental model across sizes while using space better on
larger devices.

### Decision: Keep unavailable templates explicit inside the template picker

The product still needs honest signaling about what is and is not supported.
Unavailable templates should remain explicit where the operator expects to pick
templates, but not dominate the root page.

## Risks / Trade-offs

- Moving templates out of the root page can reduce accidental discovery if the
  create entry point is too subtle, so `New provider` and `Browse templates`
  need to stay obvious.
- If the UI collapses `Provider family` and `Template` into one undifferentiated
  picker, operators may not understand the difference between a blank family
  and a pre-seeded template.
- The redesign is mostly IA and UX, so weak widget coverage could let the old
  overloaded root silently return later.

## Validation Plan

- `openspec validate add-34-mobile-provider-workspace-list-first --strict --no-interactive`
- relevant Flutter analyze and widget coverage for the `Providers` root, create
  flow, template picker, editor copy, compact drill-down/back behavior, and
  wide list-detail behavior
- manual mobile-shell validation that `Providers` opens into a list-first
  surface, that compact layouts return cleanly to the saved-provider root, and
  that templates stay reachable but secondary
