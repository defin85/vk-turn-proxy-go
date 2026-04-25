## Context

`Routing` is the last major workflow body that still exists as separate
desktop-local and mobile-local composition after the planned shared extraction
of `Home`, `Profiles`, managed-provider editing, libraries, and support
content.

Both shells still need the same core routing semantics:

- edit and review routing parameters for the current profile;
- surface mode and transport choices honestly;
- expose platform-tunnel readiness and status without hiding shell context.

## Goals / Non-Goals

- Goals:
  - share one routing-content surface across desktop and mobile;
  - keep shell-owned route wrappers local;
  - reduce routing drift after the other workflow bodies converge.
- Non-Goals:
  - merge mobile routing sheets with desktop canvas actions;
  - move platform tunnel startup policy or host supervision into shared code;
  - redesign routing IA beyond the shared body boundary.

## Decisions

- Decision: extract the routing body after the smaller workflow bodies and
  primitives.
  - Why: routing has the most shell-context coupling, so it should come after
    the lighter shared extractions prove the boundary.
  - Alternatives considered:
    - extract routing before support or libraries: rejected because the
      remaining app-local wrappers were still too heavy.

- Decision: keep sheet-level and shell-level selectors app-local.
  - Why: mobile and desktop still expose some routing adjustments through
    different shell-native controls.
  - Alternatives considered:
    - unify all selectors in one shared scaffold: rejected because it would
      blur platform fit and route ownership.

## Risks / Trade-offs

- Routing is the most likely shared body to overreach into shell-specific
  control flow.
- Platform tunnel affordances may need more app-local hooks than the simpler
  shared workflow bodies.

## Migration Plan

1. Introduce a shared routing-content API in `flutter_shell_core`.
2. Move the common routing workflow body there.
3. Rewire desktop routing canvas to the shared body.
4. Rewire mobile routing destination to the shared body while keeping local
   wrappers and selectors where needed.

