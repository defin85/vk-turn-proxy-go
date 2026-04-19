## Context
`mobile/gui_shell` already uses three surface classes:

- bottom sheets for local routing choices
- centered dialogs for some compact previews and for the current provider
  chooser
- full-screen routes for profile workspaces, QR scanning, and the owned browser

The inconsistency is not that all three exist.
The inconsistency is that similar task weights currently land in different
surface classes without a rule.

## Goals
- Define one stable taxonomy for mobile interaction surfaces.
- Make provider creation match its real complexity.
- Keep local parameter changes lightweight and anchored to the current screen.
- Prevent centered dialogs from becoming overflow containers for search, tabs,
  and library-style browsing.

## Non-Goals
- Redesign the actual provider editor fields or provider settings semantics.
- Redesign owned-browser continuation behavior.
- Force every compact contextual inspector to become a full-screen route.

## Decisions

### Decision: Classify surfaces by task weight, not by component habit

The shell will choose between sheet, dialog, and route based on what the
operator is trying to do:

| Task class | Target surface | Why |
| --- | --- | --- |
| Local, reversible choice inside the current workflow | Bottom sheet | Keeps context visible and returns the operator to the same screen immediately |
| Catalog/library flow with search, tabs, long lists, or multiple actions | Dedicated follow-on route | Scales to mobile navigation, keyboard use, and growth without crowding the root |
| Compact preview, confirmation, or short status summary | Dialog-sized overlay | Appropriate when the content is self-contained and secondary |

### Decision: Provider creation is a catalog/library flow

The mobile `New provider` chooser already includes multiple surfaces,
searchable templates, provider-family selection, and more than one action per
template in some cases.
That makes it a catalog/library flow, not a compact dialog.

Implementation target:
- open provider creation as a dedicated follow-on route from `Providers`
- keep ordinary mobile back behavior
- allow that surface to grow without revisiting the surface decision

### Decision: Routing remains the reference pattern for local pickers

`Routing profile` and `App scope` are local parameter changes inside the
current routing workflow.
They should remain bottom-sheet choices rather than routes or centered dialogs.

### Decision: Dialog-sized overlays stay small and self-contained

Dialog-sized overlays remain valid for:
- portable profile export/import preview
- destructive or risky confirmations
- short contextual status summaries

They are not valid for:
- provider family libraries
- template catalogs
- search-heavy creation flows
- tabbed multi-action browsing surfaces

## Migration Map

| Current surface | Current pattern | Target pattern |
| --- | --- | --- |
| `Routing profile` / `App scope` | Bottom sheet | Keep bottom sheet |
| `New provider` chooser | Centered dialog | Dedicated follow-on route |
| Owned browser challenge | Full-screen route | Keep full-screen route |
| Portable import/export preview | Alert dialog | Keep dialog-sized overlay |
| Compact host/status summary | Dialog-sized overlay | Keep compact overlay unless the content outgrows it |

## Risks / Trade-offs
- Provider creation will require more explicit back-navigation wiring than the
  current dialog.
- If the route is implemented poorly, it could feel heavier than the current
  dialog despite being the correct surface class.
- Some existing compact overlays may still feel visually inconsistent even
  after the taxonomy is correct; this change is primarily about surface class,
  not final visual polish.
