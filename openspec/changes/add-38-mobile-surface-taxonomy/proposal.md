# Change: [38] Unify mobile interaction surface taxonomy

## Why
The current mobile shell mixes centered dialogs, bottom sheets, and follow-on
routes for tasks with similar interaction weight.
That makes the shell feel inconsistent and leaves future UI work without a
clear rule for when to open a dialog, a sheet, or a full-screen surface.

The clearest mismatch today is between the list-style `New provider` chooser,
which currently opens as a centered dialog, and `Routing`, which uses bottom
sheets for local parameter choices.
The shell already has enough evidence to standardize these patterns instead of
re-deciding them case by case.

## Sequence
- Order: `38`
- Depends on: `add-34-mobile-provider-workspace-list-first`
- Unblocks: consistent mobile UI reviews, scalable provider-create UX, and
  future mobile shell work that needs clear surface rules before implementation

## What Changes
- Define a task-aligned mobile surface taxonomy for `mobile-gui-client`:
  bottom sheets for local quick choices, follow-on routes for catalog-style
  flows, and dialog-sized surfaces only for compact preview/confirmation/status
  content.
- Require mobile provider creation and template/family selection flows to use a
  dedicated follow-on surface instead of a centered dialog.
- Preserve `Routing` as the reference pattern for local parameter pickers and
  keep library-style flows out of alert dialogs.
- Document the intended boundary so future mobile shell work does not reopen
  the same dialog-vs-sheet-vs-route decision every time.

## Impact
- Affected specs: `mobile-gui-client`
- Affected code: `mobile/gui_shell/lib/src/ui/dashboard_page.dart`,
  `mobile/gui_shell/lib/src/ui/profile_editor.dart`,
  `mobile/gui_shell/lib/src/ui/owned_browser_challenge.dart`,
  `mobile/gui_shell/test/widget_test.dart`, and related mobile shell docs/copy
