## 1. Shell contract
- [x] 1.1 Define the desktop shell as a pane-based layout with a compact shell
      bar, a leading navigation surface, a primary body region, and a
      secondary inspector surface.
- [x] 1.2 Keep blocked or incompatible host state, tunnel failures, and other
      fail-closed conditions explicit from the primary shell surface.
- [x] 1.3 Preserve existing desktop control-plane semantics while relocating
      navigation and diagnostics surfaces.
- [x] 1.4 Define adaptive breakpoint and pane-transition rules for resizable
      desktop windows, including how navigation and inspector surfaces collapse
      without losing current draft, selection, or active context.

## 2. Desktop UI implementation
- [x] 2.1 Refactor desktop navigation so presets, managed providers, and saved
      profiles stop sharing one stacked library card and instead map into a
      small set of explicit desktop sections centered on the profile workflow
      and managed-provider workflow.
- [x] 2.2 Keep presets as seed actions inside the managed-provider workflow
      instead of a peer primary destination, and keep diagnostics/live work out
      of top-level navigation in the initial pane rollout.
- [x] 2.3 Refactor the main desktop body into task-oriented panes that fit the
      selected section and current window width without returning to the old
      dashboard grid.
- [x] 2.4 Move diagnostics, tunnel detail, event stream, and live work into
      contextual inspector surfaces with clear open/close rules, using a
      coplanar side inspector as the default large-window pattern, an
      end-drawer or equivalent overlay fallback for narrower desktop widths,
      and a bottom panel only where timeline-like content makes it a better
      fit.
- [x] 2.5 Refactor profile and provider editors so advanced or support-only
      content uses progressive disclosure and does not dominate the initial task
      pane.
- [x] 2.6 Replace the overloaded desktop shell navigation state with explicit
      controller-owned state for shell section, task selection, and inspector
      visibility instead of overloading one workspace-surface enum.
- [x] 2.7 Split shell composition so high-churn notice, event-stream, or
      activity updates do not force unnecessary rebuilds of every primary pane.

## 3. Verification
- [x] 3.1 Add or update desktop widget coverage for pane navigation, section
      switching, resize transitions, blocked/error visibility, and inspector
      surfacing.
- [x] 3.2 Run `cd desktop/gui_shell && flutter analyze && flutter test`.
- [x] 3.3 Run `openspec validate refactor-25-desktop-pane-navigation-shell --strict --no-interactive`.
