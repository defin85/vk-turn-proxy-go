## 1. Shared routing content extraction
- [ ] 1.1 Define a platform-neutral shared routing-content API in `packages/flutter_shell_core` for routing parameters, mode controls, and platform-tunnel status.
- [ ] 1.2 Move the common routing workflow body into the shared shell core without taking ownership of shell route wrappers or platform-specific selection flows.

## 2. Desktop adoption
- [ ] 2.1 Rewire the desktop routing canvas to consume the shared routing-content surface.
- [ ] 2.2 Keep desktop shell-owned route actions, canvas framing, and inspector interplay app-local.

## 3. Mobile adoption
- [ ] 3.1 Rewire the mobile routing destination to consume the shared routing-content surface.
- [ ] 3.2 Keep mobile-specific sheets, segmented controls, and destination navigation app-local where they remain product-specific.

## 4. Verification
- [ ] 4.1 Update widget coverage in `flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell` for the shared routing-content contract.
- [ ] 4.2 Run `flutter test` in `packages/flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell`.
- [ ] 4.3 Run `analyze_files` for the three Flutter roots.
- [ ] 4.4 Run `openspec validate refactor-67-flow-1-desktop-core-shared-routing-content-surface --strict --no-interactive`.

