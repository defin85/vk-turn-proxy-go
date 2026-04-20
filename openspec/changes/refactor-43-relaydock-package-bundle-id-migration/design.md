## Context

The repository already moved the human-facing product name toward
`RelayDock`, but the publish-sensitive native identifiers remain inconsistent.

Current examples in the tree include:

- Android package and namespace values under `com.defin85.mobile_gui_shell`
- macOS bundle identifiers under `com.example.guiShell`
- Linux desktop application identifiers under `com.defin85.gui_shell`
- repo-owned automation and docs that still look up the legacy Android package
  or refer to placeholder shell identities as if they were canonical

Those values do not all represent the same type of identity. Some are
publication-facing package or bundle identifiers, some are internal Dart
package names, and some are binary names. The migration needs a clear boundary
so that publication-critical identifiers move now without forcing every
internal identifier rename into the same rollout.

## Goals / Non-Goals

- Goals:
  - Establish one canonical RelayDock identifier set for mobile and desktop
    native packaging surfaces.
  - Remove placeholder or example package/bundle IDs from repo-owned packaging,
    native project metadata, and supported automation where this change
    applies.
  - Make build and verification workflows fail closed on mixed old/new publish
    identifiers.
  - Document the migration boundary so package/bundle IDs can move now without
    hiding unrelated identity cleanup.
- Non-Goals:
  - Rename Dart package names such as `gui_shell` or `mobile_gui_shell`.
  - Rename Windows binaries or staging paths such as `gui_shell.exe`.
  - Rename local artifact-role strings or local state directory roots in the
    same pass.
  - Redesign product branding, iconography, or shell UX in this change.

## Decisions

### Decision: Canonical publish identifiers use one RelayDock reverse-DNS base

The migration will standardize publish-facing native identifiers on the
RelayDock brand using one reverse-DNS base:

- Android application/package/namespace base: `com.defin85.relaydock`
- iOS app bundle identifier base: `com.defin85.relaydock`
- macOS app bundle identifier base: `com.defin85.relaydock`
- Linux GTK application identifier: `com.defin85.relaydock`

Related test-target bundle identifiers should derive from the same base through
documented suffixes instead of retaining unrelated placeholder families.

### Decision: Package and bundle identifiers come from one repo-managed publish-identity source

The repository should expose one authoritative source for publish-facing native
identifiers rather than leaving them duplicated in multiple project files and
scripts.

That source is a dedicated repo-managed publish-identity manifest, separate
from the existing version/build metadata manifest.

Repo-owned build and verification workflows must treat that manifest as
authoritative and must not silently accept drift.

### Decision: Internal shell identifiers remain explicitly separate for now

This change separates publication-critical native identifiers from internal
codebase identifiers.

That means the following remain out of scope unless a later approved change
expands the migration:

- Dart package names and import roots
- Flutter artifact-role strings
- Windows executable names and staging directory stems

Keeping that boundary explicit avoids turning a package/bundle migration into a
large multi-language rename with broader regression risk.

### Decision: Mobile publish-identity cutover must declare its state-continuity boundary

Changing the published Android `applicationId` or Apple bundle identifier does
not automatically preserve shell-owned preferences, secure-storage contents, or
install continuity.

This migration therefore needs an explicit continuity contract:

- if the repo-owned implementation adds a reviewed shared-container or
  access-group migration path, docs and verification should describe that path
  as the supported continuity mechanism
- otherwise the supported migration must be documented as a fresh-install or
  reinstall boundary, with explicit cleanup or re-entry guidance for local
  shell state and secrets

The change must not imply a seamless in-place upgrade path for mobile state
unless that continuity path is deliberately implemented and verified.

### Decision: Android cutover must treat the legacy package as a migration concern, not a canonical alias

Changing the Android `applicationId` breaks in-place continuity with previously
installed debug or local builds that used `com.defin85.mobile_gui_shell`.

Repo-owned scripts and docs should switch to the canonical RelayDock package
identifier as the supported target. If a migration helper needs to mention the
legacy package, it should do so only for uninstall or cleanup guidance rather
than treating the old package as an equal long-term runtime identity.

## Risks / Trade-offs

- Risk: Android package migration can leave old builds installed beside the new
  package or break existing smoke scripts.
  Mitigation: update repo-owned automation, ADB helpers, and runbooks in the
  same change, and make legacy package handling explicit cleanup guidance.
- Risk: mobile shell-owned preferences and secure-storage data may not survive
  the identity cutover even when the UI and build metadata compile correctly.
  Mitigation: document the supported continuity boundary explicitly and avoid
  implying seamless in-place state preservation without a reviewed migration
  path.
- Risk: iOS/macOS bundle-identifier changes can invalidate local signing,
  schemes, or test target metadata.
  Mitigation: migrate Xcode project metadata and related test identifiers as
  one reviewed unit instead of partial manual edits.
- Risk: mixed identity sources can survive if build scripts keep hard-coded
  old values.
  Mitigation: add preflight or verification checks that fail on mixed legacy
  and canonical identifiers.
- Risk: widening this migration to every internal identifier would create an
  oversized rename with low signal and high regression surface.
  Mitigation: keep internal Dart package names, artifact roles, and Windows
  binary names out of scope for this change.

## Migration Plan

1. Define the canonical RelayDock identifier set and its single repo-managed
   source of truth.
2. Migrate Android package/namespace surfaces, Apple bundle identifiers, and
   Linux application identifiers to that source.
3. Update repo-owned packaging scripts, smoke automation, and docs so they use
   the canonical identifiers, and make the mobile continuity boundary explicit
   whenever the package/bundle cutover cannot preserve local state in place.
4. Add verification that rejects mixed legacy and canonical publish
   identifiers.

## Open Questions

- Whether Windows executable naming should stay a separate follow-up change or
  be folded into a later broader artifact-identity cleanup.
