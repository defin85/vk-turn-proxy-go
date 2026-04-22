## 1. Shared managed-provider workflow extraction
- [x] 1.1 Define a platform-neutral shared managed-provider workflow API in `packages/flutter_shell_core` for descriptor-driven settings, save/delete actions, and apply-to-profile entry.
- [x] 1.2 Move the common managed-provider editor body into the shared shell core without pulling templates, route wrappers, or shell navigation into the shared package.

## 2. Mobile adoption
- [x] 2.1 Rewire mobile provider detail screens to render the shared managed-provider workflow surface while preserving the list-first `Providers` root.
- [x] 2.2 Keep mobile template catalog, save-as-template, close/back actions, and provider-root navigation app-local.

## 3. Desktop adoption
- [x] 3.1 Rewire the desktop `Providers` canvas editor to render the shared managed-provider workflow surface while preserving desktop chooser routes.
- [x] 3.2 Keep preset bootstrap, provider-family chooser entry surfaces, and desktop route ownership app-local.

## 4. Verification
- [x] 4.1 Update widget coverage in `flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell` for the shared managed-provider workflow contract.
- [x] 4.2 Run `flutter test` in `packages/flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell`.
- [x] 4.3 Run `analyze_files` for the three Flutter roots.
- [x] 4.4 Run `openspec validate refactor-64-flow-1-desktop-core-shared-managed-provider-workflow-surface --strict --no-interactive`.
