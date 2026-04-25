## Context

The desktop shell already has the right outer contract:

- compact left pad or equivalent compact drawer;
- one dominant main canvas;
- optional inspector for diagnostics and live work.

The remaining IA mismatch is inside the `Profiles` route. Desktop still uses one
workbench for both saved profiles and managed provider records, with in-canvas
section chips and workflow quick actions to compensate for the missing
top-level `Providers` entry. Mobile already avoids that by making `Profiles`
and `Providers` first-class destinations.

## Goals / Non-Goals

- Goals:
  - make `Providers` a first-class desktop task entry like mobile;
  - keep `Profiles` focused on saved profiles and profile editing;
  - reduce desktop shell noise without weakening desktop shell ownership.
- Non-Goals:
  - extract shared `Profiles` or `Providers` workflow bodies in this change;
  - merge desktop and mobile route models;
  - redesign desktop inspectors, support surfaces, or routing workspace.

## Decisions

- Decision: separate `Profiles` and `Providers` at the desktop workbench-route layer.
  - Why: the current in-canvas section switcher is IA noise, not genuine
    workflow depth.
  - Alternatives considered:
    - keep one workbench and only soften the chips: rejected because the core
      problem is missing top-level route ownership, not chip styling.
    - jump directly to shared `Profiles` and `Providers` surfaces: rejected as
      too large for the next desktop iteration.

- Decision: preserve existing canvas-routed chooser and editor flows.
  - Why: they already satisfy the desktop contract for main-canvas secondary
    surfaces and explicit back paths.
  - Alternatives considered:
    - replace chooser routes with modal or inline overlays: rejected because it
      would regress the existing desktop shell model.

- Decision: desktop shell ownership stays app-local.
  - Why: this change is about route separation and shell IA, not shared body
    extraction.
  - Alternatives considered:
    - move route ownership into `flutter_shell_core`: rejected because it would
      blur the platform-neutral boundary.

## Risks / Trade-offs

- Existing tests and shortcuts may assume `Profiles` implicitly includes
  provider-record management.
- If controller route restoration is not explicit enough, switching between
  `Profiles` and `Providers` could discard editor context.
- Removing quick actions too aggressively could hide chooser entry points unless
  the relevant workspace keeps clear task-start affordances.

## Migration Plan

1. Add a dedicated desktop `Providers` workbench route and left-pad entry.
2. Route provider-specific editor and chooser ownership through that workspace.
3. Keep `Profiles` focused on saved profiles and profile editing only.
4. Remove in-canvas section-switching chrome and update widget tests.
