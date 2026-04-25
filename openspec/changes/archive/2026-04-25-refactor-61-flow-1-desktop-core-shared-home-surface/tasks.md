## 1. Shared Home surface extraction
- [x] 1.1 Define a platform-neutral shared `Home` workflow surface API in `packages/flutter_shell_core` for selected profile, mode, primary runtime action, and support affordances.
- [x] 1.2 Move the current mobile `Home` body composition into the shared shell core without pulling platform plugins, host ownership, or navigation chrome into the shared package.

## 2. Mobile adoption
- [x] 2.1 Rewire the mobile `Home` route to render the shared `Home` body while preserving the current product-first IA and support drill-down behavior.
- [x] 2.2 Keep mobile-only adapters such as share, browser, lifecycle, and compact-vs-wide navigation app-local.

## 3. Desktop adoption
- [x] 3.1 Replace the desktop `Home` workbench body with the shared `Home` surface inside the existing left-pad-plus-canvas shell.
- [x] 3.2 Remove duplicated desktop `Home` quick actions or summary chrome that restate navigation or support surfaces already owned by the left pad or inspector.
- [x] 3.3 Preserve desktop-specific keyboard, drawer, inspector, and resize behavior.

## 4. Verification
- [x] 4.1 Update desktop and mobile widget coverage to assert the shared `Home` contract in both apps.
- [x] 4.2 Run `flutter test` in `packages/flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell`.
- [x] 4.3 Run `analyze_files` for the three Flutter roots.
- [x] 4.4 Run `openspec validate refactor-61-flow-1-desktop-core-shared-home-surface --strict --no-interactive`.
