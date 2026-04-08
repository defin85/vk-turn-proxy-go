# Change: [15] Extract shared Flutter shell core

## Why
`desktop/gui_shell` and `mobile/gui_shell` already duplicate a meaningful amount of Flutter code: control-plane models, HTTP client logic, profile draft shaping, build identity helpers, and parts of the profile/session UI.
That duplication increases the risk of semantic drift between desktop and mobile shells right before more desktop/mobile product work lands on top of them.

## Sequence
- Order: `15`
- Depends on: `add-02-desktop-gui-shell`, `add-03-mobile-gui-shell`, `add-11-build-version-surfacing`
- Unblocks: `add-05-platform-tunnel-integrations`, future desktop/mobile shell work that should not re-implement the same control-plane-facing logic twice

## What Changes
- Add one shared Flutter shell core package for platform-neutral control-plane models, client logic, build identity helpers, and reusable shell presentation/state primitives.
- Keep `desktop/gui_shell` and `mobile/gui_shell` as separate app packages with separate runtime wiring.
- Keep desktop sidecar supervision, mobile host-bridge resolution, secure storage, lifecycle, and browser handoff out of the shared core.
- Add repo-owned multi-package shell wiring so the shared package and both app packages resolve and validate together.

## Impact
- Affected specs: `flutter-shell-core`
- Affected code: `desktop/gui_shell`, `mobile/gui_shell`, new shared Flutter package, shell build/test/docs wiring
