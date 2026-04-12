## Context

The repository currently has two separate Flutter app packages:

- `desktop/gui_shell`
- `mobile/gui_shell`

That split is correct because the app bootstrap and runtime boundaries are not
the same:

- desktop talks to a supervised local `clientd` sidecar and uses desktop-local
  file-backed state
- mobile talks to a native host bridge, uses secure storage, and reacts to app
  lifecycle and browser handoff events

At the same time, both packages already duplicate or nearly duplicate
platform-neutral shell code such as:

- typed control-plane models
- control-plane HTTP client logic
- profile draft shaping
- build identity helpers and version-default glue

The repository also lacks a repo-root Flutter/Dart workspace, so shared shell
changes still rely on ad hoc per-package dependency resolution and repeated
wiring in scripts and docs.

## Goals

- Introduce one repo-owned Flutter/Dart workspace for shell packages
- Extract one shared platform-neutral shell core package
- Keep desktop and mobile as separate app packages
- Preserve repo-owned build and packaging flows
- Reduce semantic drift in shared control-plane-facing shell code

## Non-Goals

- Merge desktop and mobile into one Flutter app package
- Change the client-control contract or host capability semantics
- Move sidecar supervision, native bridge code, secure storage, lifecycle, or
  browser handoff into the shared core
- Turn the shared package into a plugin or FFI-owned package

## Decisions

### Decision: Use one repository-root Flutter/Dart workspace

The repository should add one repo-root workspace that resolves:

- `desktop/gui_shell`
- `mobile/gui_shell`
- `packages/flutter_shell_core`

That workspace becomes the canonical shared-resolution topology for shell
packages in this repository.
The workspace member list should stay explicit in the root `pubspec.yaml`
instead of using glob patterns so shell package membership remains deliberate
and reviewable.

The canonical dependency-resolution step becomes repo-root `dart pub get`.
That command is a public developer workflow for shell work in this repository,
not just an internal implementation detail hidden inside scripts.
After workspace migration:

- one root `pubspec.lock` is authoritative for workspace resolution
- one root `.dart_tool/package_config.json` is authoritative for workspace resolution
- repo-owned scripts, docs, and CI must not depend on app-local `pubspec.lock`
  or app-local `.dart_tool/package_config.json` files for workspace members

### Decision: Keep desktop and mobile as separate app packages

The desktop and mobile shells remain separate app packages with separate
`main.dart` entrypoints, package metadata, and runtime adapters.

The workspace exists to share package resolution and common code, not to erase
the boundary between desktop and mobile runtime ownership.

### Decision: Introduce one pure Flutter shared shell core package

The repository should add `packages/flutter_shell_core` as a regular Flutter
package for platform-neutral shell code.

The initial extraction target is deliberately narrow:

- control-plane models
- control-plane HTTP client logic
- profile draft shaping
- shared build identity helpers and version-default glue

Small UI primitives may move later only when they depend on Flutter and shared
shell abstractions alone.

Shared build identity code should stop at platform-neutral shaping such as
manifest-backed defaults and common `BuildIdentity` construction helpers.
App-specific artifact role and target defaults remain in desktop-local and
mobile-local wrappers.

### Decision: Keep platform-specific adapters outside the shared core

The shared shell core must not own:

- desktop sidecar discovery or process supervision
- desktop file-backed shell-state persistence
- mobile native bridge resolution or platform channel code
- mobile secure storage integration
- mobile lifecycle orchestration
- desktop or mobile browser handoff ownership
- plugin dependencies that exist only to reach those platform-specific concerns

### Decision: Extract leaf modules first

The first extraction pass should move byte-identical or nearly identical leaf
modules before considering larger UI or orchestration surfaces.

This change should not start by merging full pages, controllers, or persistence
implementations.

### Decision: Keep app-local verification entrypoints valid

The workspace must not force operators or CI to use only one opaque command.
After the workspace is introduced, these app-local entrypoints should remain
valid:

- `cd desktop/gui_shell && flutter analyze && flutter test`
- `cd mobile/gui_shell && flutter analyze && flutter test`

The repo-root workspace resolution step becomes canonical, but app-local
verification stays supported.
Build and packaging workflows may still execute from app-local directories after
repo-root resolution, but they must not reintroduce app-local resolution state
as an authoritative input.
Developer-facing shell docs should therefore present:

1. repo-root `dart pub get`
2. optional repo-root workspace inspection commands
3. app-local `flutter analyze`, `flutter test`, and packaging commands

## Alternatives Considered

### Keep the current duplication

Rejected.
It keeps the immediate wiring simple, but it preserves avoidable semantic drift
in shell code that already targets the same control-plane contract.

### Merge desktop and mobile into one Flutter app package

Rejected.
That would push sidecar supervision, secure storage, lifecycle handling, and
browser handoff into one top-level app boundary full of platform switches.

### Use path dependencies without a repo-root workspace

Rejected.
That would share code, but it would keep dependency resolution, tooling
introspection, and repo-owned verification less coherent than a single
workspace topology.

## Risks / Trade-offs

- Workspace migration can temporarily destabilize Flutter dependency resolution
  and shell scripts.
- Current shell scripts and docs still contain app-local `flutter pub get`
  assumptions that become misleading or incorrect once repository-root
  workspace resolution is the documented source of truth.
- A shared core package can grow too broad if platform-specific helpers move
  there for convenience.
- Moving larger UI surfaces too early can couple desktop and mobile semantics
  that should stay distinct.
- This change now carries a `native-build-workflows` delta even though that
  capability does not yet exist under `openspec/specs/`, so archive/promotion
  must explicitly create and promote the resulting current spec instead of
  assuming only `flutter-shell-workspace` needs promotion.

## Mitigations

- Start with leaf modules that are already identical or nearly identical.
- Keep platform-specific adapters and plugin ownership app-local.
- Update scripts, docs, and CI in the same change as the workspace wiring.
- Remove or rewrite app-local `flutter pub get` guidance anywhere the workspace
  makes repository-root `dart pub get` authoritative.
- Validate the shared package and both app packages together before landing.
- Treat archive readiness as a first-class acceptance condition: both
  `flutter-shell-workspace` and `native-build-workflows` must be promotable into
  `openspec/specs/` when this change ships.

## Validation Plan

- `dart pub get`
- `dart pub workspace list`
- `cd packages/flutter_shell_core && flutter analyze && flutter test`
- `cd desktop/gui_shell && flutter analyze && flutter test`
- `cd mobile/gui_shell && flutter analyze && flutter test`
- `openspec validate refactor-12-flutter-workspace-shell-core --strict --no-interactive`

## Archive Notes

When this change is archived, promotion must cover both affected capabilities:

- `flutter-shell-workspace`
- `native-build-workflows`

Archive readiness is incomplete until both resulting current specs exist under
`openspec/specs/` and reflect the final operator-facing workflow after
workspace migration.
