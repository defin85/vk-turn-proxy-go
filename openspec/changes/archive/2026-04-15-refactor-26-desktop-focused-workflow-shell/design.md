## Context

`refactor-25-desktop-pane-navigation-shell` established the desktop shell as a
pane-based workspace with explicit navigation and secondary inspectors.

That solved the worst dashboard problems, but it still leaves the shell too
balanced between:

- workflow switching
- current editing
- readiness/status chrome
- support inspection

The chosen static reference direction is `Focused Workflow` from the desktop
reference gallery. In practical terms, that direction means:

- one current workflow owns the visual center
- adjacent workflows stay visible but quiet
- the shell reads like one structured document, not multiple competing panes
- routine support data stays secondary until blocked or live runtime state
  makes it important

This change interprets `Focused Workflow` as a set of desktop-shell hierarchy
rules, not as a literal provider-only landing screen. The existing
`profileWorkflow` and `providerWorkflow` sections stay intact; the shell simply
stops giving them equal visual weight at all times.

## Goals

- Make the active desktop workflow feel like one dominant editor
- Reduce competition between context switching and the current task
- Keep routine ready-state chrome compact and supportive rather than dominant
- Keep diagnostics and live runtime detail on-demand in the ready path
- Preserve explicit fail-closed visibility for blocked or active runtime states
- Preserve current control-plane, provider, and session semantics

## Non-Goals

- Introduce new provider/runtime capabilities
- Change profile, provider-config, resolution, or session semantics
- Remove diagnostics, events, or tunnel detail from the desktop shell
- Force the shell into a provider-only landing path regardless of context
- Revert to the old dashboard or peer-column layout

## Decisions

### Decision: Use one dominant workflow editor

The desktop shell should treat the active workflow as the main document-like
surface.

The primary body must be visually led by one dominant editor canvas with:

- the current task title and short guidance
- a step-aware or action-aware header
- one primary action hierarchy
- progressive disclosure for advanced/support-only details

The dominant editor may still differ between `profileWorkflow` and
`providerWorkflow`, but the composition rules should remain consistent.

### Decision: Keep adjacent workflows in a quiet context lane

The shell should not present workflow switching as a second large content wall.

Adjacent workflows, recent records, and seed actions stay visible in a narrow
context lane whose job is orientation and switching, not content competition.
That lane may include:

- the current workflow index
- recent or relevant records
- seed actions such as presets

Presets remain seed actions inside the workflow model and must not become a
peer navigation taxonomy or large card grid again.

### Decision: Keep routine readiness compact

Routine ready-state assurance should help the operator without front-loading
status over the main task.

The shell should prefer a compact readiness/assurance block adjacent to the
primary workflow over a dominant shell-wide status region. Ready-state host
facts, compatibility summary, and tunnel availability remain visible, but they
should not visually outrank the editor.

### Decision: Keep support on-demand by default

Diagnostics, event stream, tunnel detail, and similar support surfaces remain
part of the desktop shell, but routine ready-state should not auto-pin them as
persistent dominant regions.

Default ready-state behavior:

- support surfaces are reachable through explicit affordances
- support inspectors open on demand
- closing support returns focus to the active editor

Escalated behavior:

- blocked or incompatible host state pins explicit guidance
- active runtime work may pin a compact summary and make the full support
  surface one step away

### Decision: Preserve state while strengthening hierarchy

This refactor is about hierarchy, not losing context.

Workflow switches, inspector open/close, and resize adaptation must preserve:

- current draft values
- current profile/provider selection
- current resolution/session context where relevant
- current inspector selection when support is open

### Decision: Treat Focused Workflow as a follow-up to the pane shell

This change builds on the pane-shell foundation instead of replacing it.

The shell can still adapt across compact, large, and extra-large desktop
widths, but those adaptive layouts should all preserve the same focused
workflow contract:

- one dominant editor
- one quiet context lane
- support as secondary by default

### Decision: Make focus and scroll ownership explicit in multi-pane layouts

The focused workflow shell still uses multiple side-by-side interactive
surfaces at desktop widths:

- a quiet context lane
- a dominant editor
- an optional support inspector

That means keyboard focus, shortcut handling, and fallback scrolling cannot be
left to incidental widget order.

The implementation should define, per layout regime:

- how focus moves between context, editor, and support surfaces
- which pane owns the default keyboard scrolling behavior
- how opening and closing support preserves or restores useful editor focus

This is primarily an operability concern for desktop, not a change to
control-plane semantics.

## Alternatives Considered

### Keep the current pane shell and only tune spacing/copy

Rejected.
The issue is not only visual density; the shell still distributes attention too
evenly between context, readiness, editing, and support.

### Implement the static Focused Workflow reference literally as provider-only desktop

Rejected.
The reference is useful as a directional artifact, but the product still needs
both `profileWorkflow` and `providerWorkflow`. The shell should adopt the
hierarchy principles without inventing a false provider-only contract.

### Give diagnostics their own persistent side lane even in the ready path

Rejected.
That returns the shell to a “multiple primary panes” reading and weakens the
main operator workflow.

## Risks / Trade-offs

- A stronger primary workflow can make adjacent workflows feel hidden if the
  context lane is too quiet.
- Support-on-demand can feel too hidden if blocked/active runtime escalation
  rules are not deterministic.
- Different editor shapes for profile and provider workflows can drift and
  break the intended “one focused shell” feeling.

## Mitigations

- Keep the context lane visible at desktop widths even when it is visually
  quieter than the primary editor.
- Define explicit escalation rules for ready, blocked, incompatible, and active
  runtime states.
- Keep shared shell primitives for step headers, action hierarchy, and support
  affordances across both workflows.
- Define focus and scroll ownership explicitly for multi-pane desktop layouts
  so the focused workflow does not become ambiguous for keyboard users.

## Validation Plan

- `cd desktop/gui_shell && flutter analyze`
- `cd desktop/gui_shell && flutter test`
- `openspec validate refactor-26-desktop-focused-workflow-shell --strict --no-interactive`
