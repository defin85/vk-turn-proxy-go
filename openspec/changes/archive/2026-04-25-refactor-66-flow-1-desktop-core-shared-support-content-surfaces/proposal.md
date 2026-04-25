# Change: [66] Extract shared Support content surfaces into shell core

## Why
After the workflow bodies and their surrounding list or frame primitives are
shared, the next repeated product layer is the content inside `Support`:

- activity and session content;
- diagnostics overview and event content;
- support state summaries that are conceptually the same even when wrapped by
  different shell chrome.

Desktop and mobile intentionally differ in support ownership: desktop uses an
optional inspector, mobile uses a dedicated support workflow. That wrapper
difference should stay, but the body-level content no longer needs to drift.

## Sequence
- Order: `66`
- Depends on:
  - `refactor-65-flow-1-desktop-core-shared-library-frame-primitives`
- Unblocks:
  - one shared typed support-content contract across desktop and mobile
  - thinner app-local support wrappers
  - clearer separation between support content and support shell ownership

## What Changes
- Extract body-level activity and diagnostics content surfaces into
  `packages/flutter_shell_core`.
- Reuse those shared support content surfaces from desktop inspectors.
- Reuse the same support content surfaces from the mobile support workflow
  while keeping mobile-specific support wrappers local.

## Impact
- Affected specs:
  - `flutter-shell-workspace`
- Affected code:
  - `packages/flutter_shell_core/lib/src/ui/...`
  - `desktop/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`

