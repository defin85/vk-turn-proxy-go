## 1. Shell contract
- [x] 1.1 Redefine the desktop shell as a single-path first-screen workflow
      where one operator task owns the initial read and secondary libraries move
      behind explicit task-start surfaces.
- [x] 1.2 Mark the desktop UX break explicitly in the contract so preserving
      first-screen co-visibility of presets, saved profiles, and managed
      providers is no longer a requirement.
- [x] 1.3 Keep blocked/incompatible host guidance and active-runtime escalation
      explicit from the primary shell surface even after secondary libraries are
      removed from the default screen.
- [x] 1.4 Preserve existing control-plane, provider, resolution, and session
      semantics while changing only desktop information architecture and default
      operator navigation.

## 2. Desktop UX redesign
- [x] 2.1 Replace the current desktop first screen with one dominant editor and
      a minimal task-switch surface instead of a full library stack plus editor
      composition.
- [x] 2.2 Move preset bootstrap into an explicit `new from preset` or
      equivalent task-start surface rather than keeping preset cards visible in
      the default provider workflow layout.
- [x] 2.3 Move saved-profile browsing and managed-provider browsing into
      explicit secondary surfaces that can be opened intentionally and closed
      back into the active workflow.
- [x] 2.4 Keep provider-family selection and reusable-record discovery within
      dedicated steps or explicit chooser surfaces instead of permanently
      expanded catalogs beside the editor.
- [x] 2.5 Tighten the active editor so the first read shows only the current
      step, concise guidance, and the next primary action hierarchy; secondary
      detail must stay in progressive disclosure or support surfaces.
- [x] 2.6 Preserve draft, selection, and support context when the operator
      enters and exits the new secondary library surfaces.
- [x] 2.7 Update desktop copy, affordances, and shortcut ownership so the new
      single-path model remains discoverable despite the intentional UX break.

## 3. Verification
- [x] 3.1 Add or update desktop widget coverage for the reduced first-screen
      surface, explicit library entry/exit, preset bootstrap from the new
      task-start surface, and preserved workflow context after returning from
      secondary libraries.
- [x] 3.2 Run `cd desktop/gui_shell && flutter analyze && flutter test`.
- [x] 3.3 Run `openspec validate refactor-27-desktop-single-path-shell --strict --no-interactive`.
