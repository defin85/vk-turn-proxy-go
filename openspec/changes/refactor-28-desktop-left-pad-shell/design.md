## Context

The current desktop shell still tries to earn clarity by stacking explanatory
cards next to the main workspace. That is not solving the problem anymore.
It keeps reintroducing a second reading lane that competes with the editor and
creates a pseudo-master-pane even after the earlier single-path changes.

The operator should not have to read:

- a workflow card
- a focus card
- a current-task card
- an action card
- and then the real editor

to understand what screen they are on.

This change treats the current card stack as the wrong shell primitive.
The correct primitive is a desktop left pad plus one main canvas.

## Goals

- Make the desktop shell read as one task surface with one persistent left pad
- Remove duplicated summary cards for the same active entity
- Stop using modal overlays as the routine way to browse profiles, presets, or
  provider records
- Keep diagnostics and live work secondary through the inspector model
- Preserve typed host and runtime semantics

## Non-Goals

- Add new profile, provider, resolution, or session capabilities
- Change the local control-plane contract
- Make diagnostics or live work first-class left-pad destinations
- Turn the shell into a multi-pane dashboard again

## Decisions

### Decision: Use a real left pad, not a summary wall

The persistent left surface should behave like a control pad:

- workflow switch
- explicit task-entry actions
- active selection identity
- short host/runtime status cues

It should not behave like a vertical stack of explanatory cards.

### Decision: The main canvas owns all substantive task content

The central workspace should show exactly one substantive surface at a time.
Examples:

- profile editor
- saved-profile picker
- managed-provider picker
- preset picker
- provider-family chooser
- managed-provider editor

When one of these is active, the shell should not show a second card elsewhere
that tries to summarize the same task.

### Decision: Replace modal-first library entry with canvas routes

Routine library and chooser flows should become full-height canvas routes with
an explicit back path to the originating task.

This is preferable to modal overlays because:

- it reads as deliberate task switching instead of temporary popups
- it avoids shrinking the main interaction model into layered dialogs
- it fits desktop left-pad navigation better than modal interruption

Small confirm dialogs are still acceptable for destructive actions, but list
and chooser workflows should not default to modal surfaces.

### Decision: Keep left-pad items compact and command-oriented

The left pad should prefer rows, grouped actions, and compact tokens over large
cards. It may show:

- `Profiles` and `Providers` workflow entries
- `New draft`, `Saved profiles`, `Provider records`, `Presets`
- active item labels such as current draft/profile/record name
- compact host badges

It should avoid descriptive blocks that restate what the main canvas already
shows.

### Decision: Separate workflow, canvas route, and inspector state

The shell state model should explicitly separate:

- top-level workflow: profile vs provider
- canvas route: editor vs picker vs chooser
- inspector visibility and active inspector pane

This prevents the current layout from overloading one area of the UI with both
navigation and detail explanation.

### Decision: Keep the header operational, not editorial

The top header should continue to own:

- local host state
- contract/build summary
- reconnect/refresh
- diagnostics/live work access
- compact fail-closed readiness copy

It should not become a second editor or a replacement for the left pad.

## Target Layout

### Shell chrome

- compact operational header
- main body with `left pad | main canvas | optional inspector`

### Left pad

- workflow switcher
- task-entry group relevant to the active workflow
- active selection strip
- compact status cues only when materially useful

### Main canvas

- single active task route
- route header with title, breadcrumb/back affordance, and task-local actions
- body fully dedicated to the active route

### Inspector

- diagnostics/live work only
- hidden by default
- right-side secondary surface

## Canvas Routes

### Profile workflow

- `profile-editor`
- `saved-profile-picker`
- `managed-provider-picker-for-profile`

### Provider workflow

- `managed-provider-editor`
- `preset-picker`
- `managed-provider-picker`
- `provider-family-picker`

Each route should preserve its return target and not clear draft state unless
the operator explicitly chooses a different entity or starts a new draft.

## Anti-Patterns To Remove

- persistent "Current focus" card stack
- persistent "Current task" summary cards beside the active editor
- large action cards above the editor that restate the route already in focus
- modal-first browsing for routine library entry
- showing a list/card summary for the same entity that is already open in the
  central editor
- any default ready-state composition that still reads as multiple equal-weight
  card regions instead of one dominant canvas

## Risks / Trade-offs

- A route-based canvas model is a bigger visual break than the current shell
- Operators may initially miss the earlier always-visible summary cards
- Moving list/picker flows into the main canvas increases the importance of
  clear back navigation and route titles

## Mitigations

- Make the left pad stable across workflows so only the canvas changes
- Use explicit route headers and back affordances
- Keep active selection visible in one compact place in the left pad
- Add widget coverage for route entry, route exit, state preservation, and
  inspector coexistence

## Acceptance Gate

The change is not acceptable if the routine ready-state first screen still
reads like a dashboard of several peer card zones.

The intended first-read hierarchy is:

- left pad for compact command/navigation
- one dominant canvas for the active task route
- optional right inspector only when explicitly opened

Any implementation that keeps a separate persistent summary or action region
competing with the active route should be treated as incomplete even if a rail
or pad is technically present.

## Migration Plan

1. Introduce a dedicated desktop canvas-route state model.
2. Replace the current left summary/card stack with a compact left pad.
3. Convert saved-profile, preset, provider-record, and family selection flows
   from modal/secondary-card entry into canvas routes.
4. Remove duplicated context cards from the main desktop shell.
5. Refresh widget tests, screenshots, and acceptance references.

## Open Questions

- Whether the left pad should include a tiny active-item list for recent items
  or stay strictly command-only can stay open, but it must remain compact and
  must not become a second detail pane.
