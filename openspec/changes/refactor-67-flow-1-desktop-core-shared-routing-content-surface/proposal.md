# Change: [67] Extract the shared Routing content surface into shell core

## Why
The last large body-level workflow duplication after `Home`, `Profiles`,
`Providers`, libraries, and support is `Routing`. Both shells expose the same
core concepts:

- current profile routing parameters;
- mode and transport controls;
- platform-tunnel readiness and state;
- explicit task actions around starting, saving, or adjusting routing.

Desktop and mobile still wrap that content differently, but the product-facing
routing body is now the main remaining candidate for shared extraction.

## Sequence
- Order: `67`
- Depends on:
  - `refactor-65-flow-1-desktop-core-shared-library-frame-primitives`
- Unblocks:
  - one shared routing-content contract across desktop and mobile
  - thinner app-local routing pages
  - a clearer stopping point for desktop/mobile workflow-body unification

## What Changes
- Extract the body-level routing workflow surface into
  `packages/flutter_shell_core`.
- Reuse that shared routing content surface from the desktop routing canvas.
- Reuse the same routing content surface from the mobile routing destination
  while keeping shell-owned wrappers local.

## Impact
- Affected specs:
  - `flutter-shell-workspace`
- Affected code:
  - `packages/flutter_shell_core/lib/src/ui/...`
  - `desktop/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`

