## 1. Route separation
- [x] 1.1 Add a first-class desktop `Providers` workbench route and task-entry affordance in the left pad and compact drawer.
- [x] 1.2 Keep the desktop `Profiles` workbench profile-only and the desktop `Providers` workbench provider-only while preserving existing canvas-routed chooser and editor flows.

## 2. Desktop UI cleanup
- [x] 2.1 Remove in-workbench profile/provider section-switching chrome and route-restating quick actions that only compensate for the missing top-level `Providers` route.
- [x] 2.2 Preserve desktop-specific keyboard, compact drawer, inspector, and resize behavior while switching between the separated workspaces.

## 3. Verification
- [x] 3.1 Update desktop widget coverage for distinct `Profiles` and `Providers` task entry and preserved workflow context.
- [x] 3.2 Run `flutter test` in `desktop/gui_shell`.
- [x] 3.3 Run `analyze_files` for `desktop/gui_shell`.
- [x] 3.4 Run `openspec validate refactor-62-flow-1-desktop-profiles-providers-route-separation --strict --no-interactive`.
