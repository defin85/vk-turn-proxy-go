## Context

The repository now has two Flutter app packages:

- `desktop/gui_shell` for the desktop shell over `clientd`
- `mobile/gui_shell` for the mobile shell over a native mobile host bridge

Those app packages should remain separate because they have different runtime wiring:

- desktop launches or discovers a compatible sidecar and uses file-backed shell state
- mobile resolves a native host bridge, uses secure storage, and reacts to app lifecycle and browser handoff events

At the same time, both packages already duplicate a platform-neutral control-plane-facing layer:

- typed control-plane models
- the HTTP client and negotiation logic
- profile draft shaping
- build identity helpers and version-default glue
- parts of the profile/session/event UI surface

The duplication is already large enough to create drift risk across desktop and mobile shells.
Future work such as platform tunnel integrations and richer challenge flows would make that drift more expensive.

## Goals

- Reduce duplicated platform-neutral Flutter shell code across desktop and mobile
- Preserve separate desktop and mobile app packages and delivery flows
- Keep platform host wiring explicit and local to each shell
- Keep build/version metadata helpers aligned across all shell packages
- Make shell package dependency resolution and analysis more coherent as shared code is introduced

## Non-Goals

- Collapse desktop and mobile into one Flutter app package
- Change the control-plane contract or host capability semantics
- Move sidecar supervision, platform channels, secure storage, or browser handoff into a shared package
- Introduce platform tunnel behavior in this change

## Decisions

### Decision: Extract one shared Flutter shell core package

The repository should introduce one shared Flutter package that owns platform-neutral shell code reused by both desktop and mobile shells.

That shared package should contain only code that does not depend on a desktop sidecar model or a mobile native bridge model.
The initial extraction target includes:

- control-plane models
- control-plane HTTP client
- profile draft shaping
- build identity and shared version-default helpers
- reusable shell presentation/widgets that depend only on Flutter and shared shell abstractions

### Decision: Keep desktop and mobile as separate app packages

The desktop shell and mobile shell should remain separate Flutter app packages.

Desktop and mobile have different runtime ownership models, package outputs, and startup constraints.
Keeping them separate avoids a single app package that is full of platform-switching logic for sidecar supervision, native bridge resolution, secure storage, and lifecycle handling.

### Decision: Keep platform host adapters and persistence outside the shared core

The shared shell core must not own:

- desktop sidecar discovery or `clientd` process supervision
- mobile native host-bridge resolution or platform channel code
- mobile secure storage integration
- desktop file-backed shell-state persistence
- platform lifecycle and browser handoff orchestration

Those responsibilities stay in thin app-specific adapter layers so the shared package remains honest about what is truly platform-neutral.

### Decision: Use repo-owned multi-package shell wiring

Once the shared shell package exists, the repository should wire the shell packages together as one repo-owned multi-package Dart/Flutter workspace or equivalent shared path-based package layout.

The preferred direction is a Dart pub workspace because it gives one shared resolution for the shell packages and improves monorepo ergonomics for analysis and dependency alignment.

## Alternatives Considered

### Keep the current duplication

This keeps packaging simple in the short term, but it means every desktop/mobile shell change must be copied and reviewed twice.
That is already happening for core control-plane-facing code and common widgets.

### Merge everything into one Flutter app package

This would reduce duplication, but it would mix two different runtime models into one top-level app:

- desktop sidecar supervision over local IPC/HTTP
- mobile embedded/bridged host behavior with native lifecycle constraints

That is the wrong abstraction boundary for this repository.

## Risks / Trade-offs

- Shared-package extraction can temporarily destabilize Flutter build wiring across both shells.
- A shared package can become too broad if platform-specific helpers are moved into it for convenience.
- A repo-level Dart workspace adds another root-level toolchain concern that must stay compatible with the rest of the repository.

## Mitigations

- Extract only files that are already identical or nearly identical first.
- Keep explicit app-local adapters for host bootstrap, persistence, and platform events.
- Validate both shells on every step of the extraction instead of landing package moves without app-level verification.

## Validation Plan

- Add focused tests for the shared shell core package
- Re-run desktop shell analysis/tests after the extraction
- Re-run mobile shell analysis/tests after the extraction
- Validate the OpenSpec change with `openspec validate refactor-15-shared-flutter-shell-core --strict --no-interactive`
