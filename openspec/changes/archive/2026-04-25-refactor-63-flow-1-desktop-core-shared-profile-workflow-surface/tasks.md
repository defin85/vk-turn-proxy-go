## 1. Shared profile workflow extraction
- [x] 1.1 Define a platform-neutral shared `Profile` workflow surface API in `packages/flutter_shell_core` for profile draft editing, managed/custom provider mode switching, and portable-transfer entry affordances.
- [x] 1.2 Move the common profile workflow body into the shared shell core without pulling shell navigation, platform plugins, or app-owned page scaffolds into the shared package.

## 2. Mobile adoption
- [x] 2.1 Rewire the mobile profile workspace page to render the shared profile workflow surface while preserving current root actions and current-profile targeting behavior.
- [x] 2.2 Keep mobile-native share, QR, file import/export, and route transitions app-local around the shared profile body.

## 3. Desktop adoption
- [x] 3.1 Rewire the desktop `Profiles` canvas to render the shared profile workflow surface while preserving desktop chooser routes and left-pad-owned task entry.
- [x] 3.2 Keep desktop file-based transfer wrappers and shell-owned route actions app-local.

## 4. Verification
- [x] 4.1 Update widget coverage in `flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell` for the shared profile workflow contract.
- [x] 4.2 Run `flutter test` in `packages/flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell`.
- [x] 4.3 Run `analyze_files` for the three Flutter roots.
- [x] 4.4 Run `openspec validate refactor-63-flow-1-desktop-core-shared-profile-workflow-surface --strict --no-interactive`.
