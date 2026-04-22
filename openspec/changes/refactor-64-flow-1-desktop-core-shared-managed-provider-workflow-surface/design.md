## Context

The desktop shell now has a dedicated `Providers` workspace, and the mobile
shell already treats reusable provider records as a first-class list-first
workflow. Despite that IA alignment, both apps still keep separate
managed-provider editor implementations.

The shared target here is narrower than the full `Providers` destination:

- reusable provider record editing;
- descriptor-driven settings rendering;
- save and delete actions;
- apply-to-profile affordance.

Template catalogs, presets, and shell-owned entry wrappers still differ between
desktop and mobile.

## Goals / Non-Goals

- Goals:
  - share one managed-provider workflow body across desktop and mobile;
  - keep template and preset ownership honest instead of faking full parity;
  - reduce drift before extracting shared library primitives.
- Non-Goals:
  - merge desktop `Providers` route ownership with mobile list-first root
    ownership;
  - move mobile templates into desktop scope implicitly;
  - redesign provider-family chooser semantics.

## Decisions

- Decision: share the managed-provider editor body, not the full `Providers`
  destination.
  - Why: the editor is already the common surface, while the surrounding root
    workflow still differs intentionally between desktop and mobile.
  - Alternatives considered:
    - share the entire `Providers` destination now: rejected because mobile
      templates and desktop shell route wrappers are not yet aligned.

- Decision: keep template and preset affordances app-local.
  - Why: mobile templates and desktop preset bootstrap are real product
    differences, not accidental duplication.
  - Alternatives considered:
    - push those affordances into one shared editor footer: rejected because it
      would either overfit mobile or pollute desktop with non-native ownership.

## Risks / Trade-offs

- The shared editor API could become too broad if template-specific and
  preset-specific behaviors are not clearly separated from the common record
  workflow.
- Desktop could lose some provider-specific task entry clarity if too many
  shell-owned entry points are hidden behind the shared surface.
- Mobile could regress if list-first `Providers` semantics leak into the shared
  editor body rather than staying in the app-local root.

## Migration Plan

1. Define a shared managed-provider workflow API in `flutter_shell_core`.
2. Move the common editor body there.
3. Rewire mobile provider detail screens to the shared body while keeping
   template ownership local.
4. Rewire desktop `Providers` editor to the shared body while keeping preset
   and chooser entry surfaces local.

