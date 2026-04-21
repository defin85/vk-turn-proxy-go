## Context

The current repository-owned Android packaging workflow is explicitly a local
debug lane. It builds `app-debug.apk`, stages local build metadata, and can
inject a workstation-local WireGuard development profile asset into the
packaged app for the debug `android_vpn_service` path.

That is useful for physical-device development, but it is the wrong contract
for Google Play distribution. A store-target release needs a signed upload
artifact, explicit signing-key ownership, and a packaging boundary that keeps
repo-local development state out of the published app.

The repository also still carries an Android `release` fallback that signs with
the debug config. That is acceptable only as a temporary local convenience; it
must not remain part of a release lane that claims store readiness.

## Goals / Non-Goals

- Goals:
  - Add one documented repo-owned Android release workflow for Google Play.
  - Require explicit upload-key signing inputs and remove silent debug-signing
    fallback from the release path.
  - Keep Play-target Android packages aligned with the packaged-host production
    slice rather than with debug-only workstation conveniences.
  - Document the operator-owned Google Play submission handoff around the
    release artifact instead of leaving it implicit.
  - Make release preflight fail closed when the Android config or toolchain no
    longer satisfies the repo-managed Play submission floor.
- Non-Goals:
  - Automate Play Console publishing through the Google Play Developer API.
  - Create or manage Google accounts, payments profiles, legal texts, or
    policy declarations on behalf of the operator.
  - Rework the existing local debug APK workflow beyond the separation required
    to keep debug-only behavior out of the release lane.
  - Define iOS, desktop-store, or non-Play mobile publication workflows.

## Decisions

### Decision: Keep separate debug and Play release lanes

The existing debug APK workflow should remain available for local device work.
Google Play distribution should use a separate release lane with different
artifact type, signing rules, and packaging checks.

That keeps operator iteration fast without letting local conveniences redefine
the publication contract.

### Decision: Release signing stays operator-supplied and out of the repository

The repository should not store upload keystores, passwords, or private signing
material.

The Play release workflow should instead read explicit operator-supplied
signing inputs from documented environment variables or local untracked config
and fail before staging artifacts when those inputs are incomplete or invalid.

### Decision: The staged release artifact should match the Play upload surface

The release lane should stage the artifact that operators actually upload to
Google Play, rather than pretending a debug APK is equivalent.

That means the documented staged release artifact should be an Android App
Bundle (`.aab`). If the workflow also stages an APK for local smoke or archive
purposes, that APK is secondary and should not replace the upload artifact in
the contract.

### Decision: Play-target release packages must exclude repo-local seeded assets

The debug packaging lane may stage repo-local development assets such as
`phone1.conf`, but the Play-target release lane must not.

Release packaging should remain aligned with the production mobile slice:
- packaged host startup stays the default
- development bridge overrides remain explicit non-store flows
- workstation-local seeded assets do not become part of the published app

### Decision: The repo owns the build and staging path, while the operator owns Play Console

The repository should own:
- release signing preflight
- artifact generation
- staged output layout
- local verification guidance

The operator still owns:
- Play App Signing enrollment choices
- release-track selection
- store listing content
- policy and app-content declarations

The docs should make that split explicit so the workflow does not imply that a
repo-owned shell command can finish publication by itself.

### Decision: Release preflight uses a repo-managed Play submission floor

Google Play policy requirements change over time, especially around target API
levels. The repository should therefore own an explicit minimum release floor
for the Play-target Android lane and fail closed when the Android config falls
below that floor.

That keeps publication blockers visible in the build workflow instead of only
surfacing them after an upload attempt in Play Console.

## Risks / Trade-offs

- Risk: release-signing setup becomes cumbersome for local operators.
  Mitigation: document one small untracked config/env contract and keep the
  release lane separate from the debug lane so only store-target packaging pays
  that cost.
- Risk: the repo-managed Play submission floor drifts as Google changes policy.
  Mitigation: keep the floor explicit and documented so updates are small and
  reviewable instead of buried in accidental Gradle defaults.
- Risk: developers may continue using the debug APK as if it were publishable.
  Mitigation: name and stage the release artifact distinctly and document that
  the Play-target contract is the signed AAB lane.
- Risk: repo-local development assets may leak into the published package if
  release and debug staging keep sharing logic.
  Mitigation: add explicit exclusion checks and release-only verification.
- Risk: docs can overpromise by describing policy declarations as if the repo
  can automate them.
  Mitigation: keep the handoff language explicit: the repo prepares the
  artifact and the operator completes Play Console setup.

## Migration Plan

1. Define the Play-target Android release artifact and signing contract.
2. Add the repo-owned release entrypoint and explicit signing preflight.
3. Separate release packaging from debug-only seeded assets and other
   workstation-local conveniences.
4. Document the operator handoff from staged artifact to Google Play Console.
5. Add checks that prove the release lane fails closed on missing signing
   inputs, insufficient Android release prerequisites, or leaked debug assets.

## Open Questions

- Whether the project should let Google generate the app-signing key in Play
  App Signing or upload a developer-managed signing key from the start.
- Whether the first supported rollout target should be internal testing only or
  closed testing, given account-type-specific Play review constraints.
