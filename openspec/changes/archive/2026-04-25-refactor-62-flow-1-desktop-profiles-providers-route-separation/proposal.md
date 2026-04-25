# Change: [62] Separate desktop Profiles and Providers into distinct top-level workspaces

## Why
The desktop shell is still noisier than the mobile shell in one important way:
it mixes `Profiles` and reusable `Provider records` inside one workbench route
and relies on in-canvas section chips plus workflow quick actions to switch
between them.

That does not add meaningful depth. It restates navigation that should belong to
the left pad and makes the desktop `Profiles` area read as a shell-owned
workspace switcher rather than a focused product workflow.

The mobile shell already proved the cleaner IA: `Profiles` and `Providers` are
separate first-class destinations. The next narrow desktop step should adopt
that route separation while keeping the desktop-specific left pad, dominant
canvas, keyboard, drawer, and inspector model intact.

## Sequence
- Order: `62`
- Depends on:
  - `add-30-flow-1-desktop-core-vpn-workbench-shell`
  - `refactor-61-flow-1-desktop-core-shared-home-surface`
- Unblocks:
  - quieter desktop task entry without mixed section-switching chrome
  - later shared extraction of `Profiles` and `Providers` workflow bodies
  - closer IA parity between desktop and mobile without collapsing the two apps

## What Changes
- Promote desktop reusable-provider management to a first-class top-level
  `Providers` workspace entry in the left pad and compact drawer.
- Keep the desktop `Profiles` workspace profile-only instead of mixing
  provider-record actions into the same route through section chips.
- Remove desktop-local in-workbench section switching and route-restating quick
  actions that only compensate for the missing top-level `Providers` entry.
- Preserve existing desktop canvas-routed chooser flows, keyboard shortcuts,
  compact drawer behavior, inspector behavior, and width adaptation.

## Impact
- Affected specs:
  - `desktop-gui-client`
- Affected code:
  - `desktop/gui_shell/lib/src/control/desktop_shell_controller.dart`
  - `desktop/gui_shell/lib/src/ui/dashboard_page.dart`
  - `desktop/gui_shell/test/widget_test.dart`
