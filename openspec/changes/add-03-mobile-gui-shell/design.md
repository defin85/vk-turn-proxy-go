## Context

Mobile cannot simply reuse the desktop sidecar model because:

- Android and iOS constrain background execution differently
- secure storage and browser handoff are platform-native concerns
- system-wide traffic capture needs separate platform tunnel APIs

So the first mobile slice should focus on the app shell and embedded host integration.

## Goals

- Deliver one mobile client shell for Android and iOS
- Reuse the same control-plane semantics as desktop
- Store secrets through platform-native secure storage
- Support challenge handoff and session status without requiring a terminal

## Non-Goals

- Full system tunnel or route management in this change
- A separate mobile-only runtime contract
- Provider-specific UI logic beyond challenge orchestration

## Decisions

### Decision: Use one mobile shell with thin platform host bridges

The mobile GUI should share one application shell while isolating Android/iOS specifics in thin bridge code.

### Decision: Implement the mobile shell in Flutter

The mobile GUI shell uses Flutter as the canonical UI stack.
That keeps Android and iOS on the same application model as the planned desktop shell and limits platform-specific code to thin host bridges, secure-storage integration, browser handoff, and later tunnel APIs.

### Decision: Embed or host the runtime through a mobile bridge, not through shell commands

Mobile shells must use an embedded or bridged host layer rather than spawning CLI processes and scraping output.

### Decision: Keep system tunnel work out of the first mobile slice

Android `VpnService`, iOS Network Extension, and related routing concerns are deferred to a later change so the first mobile app remains deliverable.

## Risks / Trade-offs

- Mobile background limits can interrupt long-running sessions until platform tunnel work exists
- Embedding the host on mobile increases packaging and ABI complexity
- Browser challenge state continuity must be stable across app lifecycle events

## Validation Plan

- Mobile integration tests for profile/session/challenge flows against a mocked host
- At least one embedded-host smoke flow per mobile platform
- `openspec validate add-03-mobile-gui-shell --strict --no-interactive`
