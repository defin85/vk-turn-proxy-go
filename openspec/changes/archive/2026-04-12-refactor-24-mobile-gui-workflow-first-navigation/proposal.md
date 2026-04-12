# Change: [24] Refactor mobile GUI into workflow-first navigation

## Why
The current mobile shell exposes almost the same surfaces as desktop, but it
still arranges them as one long fixed-height dashboard.

That keeps all capabilities technically reachable, yet it is not a mobile-first
workflow: the operator scrolls through stacked cards for host state, tunnel
state, profile editing, resolutions, sessions, and events, and resolution cards
can expose too many parallel actions for a phone-sized screen.

## Sequence
- Order: `24`
- Depends on: `add-03-mobile-gui-shell`,
  `add-21-provider-defined-entry-fields`,
  `refactor-12-flutter-workspace-shell-core`
- Unblocks: later Android/iOS tunnel UX polish under
  `add-17-android-vpn-service-ready-path`

## What Changes
- Replace the monolithic mobile dashboard with workflow-first navigation where
  the primary "profile -> resolve/start" path is separate from activity and
  diagnostics surfaces.
- Remove fixed-height stacked panels and nested-scroll assumptions from the
  first-class mobile flow.
- Reduce mobile action density by keeping one clear primary action per context
  and moving the rest into progressive disclosure such as overflow menus or
  sheets.
- Keep tunnel readiness, host diagnostics, event stream, and advanced runtime
  controls reachable, but secondary to the common phone workflow.

## Impact
- Affected specs: `mobile-gui-client`
- Affected code: `mobile/gui_shell/lib/src/ui/...`,
  `mobile/gui_shell/test/...`, mobile shell docs/screenshots
