## Context

The repository already has shared shell visuals, a shared `Home` body, and the
next planned shared profile/provider workflow bodies. What remains visibly
duplicated after that is the smaller but repeated scaffolding around those
workflows:

- library surfaces for saved profiles and reusable providers;
- repeated empty, hint, and summary cards;
- section headers and body frames reused across desktop and mobile.

These pieces are good candidates for shared extraction because they are body-
level primitives, not shell-owned navigation structures.

## Goals / Non-Goals

- Goals:
  - reduce repeated library and section-frame code across both shells;
  - make later shared workflow extraction cheaper and more consistent;
  - keep app-local destination chrome and route ownership intact.
- Non-Goals:
  - unify desktop and mobile navigation shells;
  - flatten all product differences into one generic list primitive;
  - refactor support or routing content in the same change.

## Decisions

- Decision: extract body-level list and frame primitives after the profile and
  managed-provider workflow bodies exist.
  - Why: the shared body contracts define the right ownership boundary for the
    surrounding primitives.
  - Alternatives considered:
    - extract frame primitives first: rejected because the shared body inputs
      are now clearer than before `63` and `64`.

- Decision: keep mobile and desktop page scaffolds local.
  - Why: headers, rails, inspectors, overflow actions, and destination shells
    still belong to each app.
  - Alternatives considered:
    - share full workflow root pages: rejected because that would collapse
      shell-owned structure into body-level code again.

## Risks / Trade-offs

- Over-generalized list primitives could erase meaningful differences between
  mobile list-first roots and desktop split-pane libraries.
- If shared frame primitives become too opinionated, desktop density or mobile
  touch ergonomics could regress.

## Migration Plan

1. Introduce shared list and frame primitives in `flutter_shell_core`.
2. Rewire desktop libraries to those primitives.
3. Rewire mobile roots where the product semantics match.
4. Update tests before moving on to support or routing extraction.

