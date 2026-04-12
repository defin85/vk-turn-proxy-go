## Context

`add-03-mobile-gui-shell` established the Flutter shell and the mobile host contract, but the Android app still reaches `Mobile host blocked` on a real device because no packaged host exists behind that contract.

The production Android slice needs:

- one installable app package
- one bundled host/runtime delivery unit
- no external desktop sidecar dependency
- no first-run host download flow
- no silent fallback from a missing packaged host into a development-only bridge

## Goals

- Ship an Android app that includes a compatible mobile host by default
- Reuse the canonical runtime and control-plane semantics rather than inventing a second mobile-only protocol
- Keep GUI and embedded host in the same release/version unit
- Preserve an explicit development bridge path for dogfooding and debugging

## Non-Goals

- iOS embedded host delivery in this change
- Android `VpnService` or device-wide traffic capture in this change
- Runtime host downloads, self-updaters, or external companion apps
- Provider-specific mobile UI beyond the existing typed session/challenge model

## Decisions

### Decision: Scope this change to Android embedded host delivery

The missing production path is concrete on Android today.
This change should solve Android packaging and runtime ownership without blocking on iOS-specific packaging, entitlement, and background models.

### Decision: Package the host with the app instead of downloading or side-loading it

Production Android installs must carry their compatible host/runtime in the same APK/AAB release unit as the GUI.
The app must not require an external `clientd`, an operator-managed companion app, or a network fetch to become runtime-ready.

### Decision: Reuse the canonical runtime through an Android host wrapper, not a second network engine

The embedded Android host should reuse the existing provider, session, transport, and control-plane semantics from the canonical repository.
New Android-specific code should focus on process/service ownership, native packaging, and bridge wiring rather than reimplementing transport behavior.

### Decision: Use an app-owned Android host bridge in production and keep external HTTP only for development

The production Android path should talk to the packaged host through an app-owned bridge.
That bridge may adapt the existing control-plane semantics to Android-native wiring, while explicit external HTTP overrides remain available only for documented development workflows.

### Decision: Keep GUI and packaged host in one versioned release unit

The Android GUI build and embedded host build should be stamped and shipped together so version skew is a packaging bug, not an operator-managed runtime state.
If the packaged host is missing, fails bootstrap, or negotiates as incompatible, the app must fail closed and report the packaged-host problem explicitly.

## Risks / Trade-offs

- Bundling the host increases Android ABI and packaging complexity
- Android service/process lifecycle can interrupt long-running sessions until later platform tunnel work exists
- A production bridge that diverges too far from the existing control-plane semantics would create an unnecessary second contract
- Development override paths can leak into release assumptions unless they are explicitly gated and documented

## Validation Plan

- Host-backed integration coverage for Android GUI-to-host lifecycle, profile/session operations, challenge flows, and fail-closed bootstrap behavior
- At least one Android packaging smoke that proves the packaged host path reaches `ready` without an external `clientd` or `VKTP_MOBILE_HOST_URL`
- `openspec validate add-14-android-embedded-mobile-host --strict --no-interactive`
