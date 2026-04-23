## 1. Shared support content extraction
- [x] 1.1 Define platform-neutral shared support-content APIs in `packages/flutter_shell_core` for activity, sessions, diagnostics overview, and event content.
- [x] 1.2 Move the common support-content bodies into the shared shell core without taking ownership of inspector, page, or destination wrappers.

## 2. Desktop adoption
- [x] 2.1 Rewire desktop inspector content to consume the shared support-content surfaces.
- [x] 2.2 Keep desktop inspector shell ownership, support triggers, and shell bar context app-local.

## 3. Mobile adoption
- [x] 3.1 Rewire the mobile support workflow to consume the shared support-content surfaces.
- [x] 3.2 Keep mobile support route ownership, wide toolbar composition, and embedded-browser reset affordances app-local.

## 4. Verification
- [x] 4.1 Update widget coverage in `flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell` for shared support content.
- [x] 4.2 Run `flutter test` in `packages/flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell`.
- [x] 4.3 Run `analyze_files` for the three Flutter roots.
- [x] 4.4 Run `openspec validate refactor-66-flow-1-desktop-core-shared-support-content-surfaces --strict --no-interactive`.
