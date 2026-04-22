## 1. Shared library and frame extraction
- [ ] 1.1 Define platform-neutral shared library surfaces and workflow-frame primitives in `packages/flutter_shell_core` for saved-profile lists, managed-provider lists, section headers, and empty/hint states.
- [ ] 1.2 Move the common list and frame composition into the shared shell core without taking ownership of desktop or mobile page scaffolds.

## 2. Desktop adoption
- [ ] 2.1 Rewire desktop `Profiles` and `Providers` workspaces to consume the shared library and frame primitives.
- [ ] 2.2 Keep desktop left-pad routing, inspector ownership, and canvas-specific wrappers app-local.

## 3. Mobile adoption
- [ ] 3.1 Rewire mobile `Profiles` and `Providers` roots to consume the shared library and frame primitives where the current composition is product-equivalent.
- [ ] 3.2 Keep mobile page headers, overflow actions, list-first root ownership, and destination navigation app-local.

## 4. Verification
- [ ] 4.1 Update widget coverage in `flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell` for shared library and frame primitives.
- [ ] 4.2 Run `flutter test` in `packages/flutter_shell_core`, `desktop/gui_shell`, and `mobile/gui_shell`.
- [ ] 4.3 Run `analyze_files` for the three Flutter roots.
- [ ] 4.4 Run `openspec validate refactor-65-flow-1-desktop-core-shared-library-frame-primitives --strict --no-interactive`.

