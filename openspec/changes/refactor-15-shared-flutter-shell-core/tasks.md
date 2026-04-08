## 1. Shared shell core contract
- [ ] 1.1 Define the platform-neutral Flutter shell core boundary for control-plane models, client logic, build identity helpers, and reusable shell presentation/state primitives
- [ ] 1.2 Define which desktop and mobile responsibilities remain outside the shared core
- [ ] 1.3 Define the repo-owned multi-package dependency/workspace strategy for the shell packages

## 2. Package extraction
- [ ] 2.1 Create the shared Flutter shell core package and move the duplicated platform-neutral control-plane code into it
- [ ] 2.2 Move reusable shell UI/presentation helpers into the shared package without introducing platform host assumptions
- [ ] 2.3 Refactor `desktop/gui_shell` to consume the shared package while keeping sidecar supervision and file-backed desktop state local
- [ ] 2.4 Refactor `mobile/gui_shell` to consume the shared package while keeping native bridge resolution, secure storage, lifecycle handling, and browser handoff local
- [ ] 2.5 Update shell build, dependency, and documentation wiring for the shared package layout

## 3. Verification
- [ ] 3.1 Add or update tests for the shared shell core package and its reused UI/control-plane helpers
- [ ] 3.2 Run `cd desktop/gui_shell && flutter analyze && flutter test`
- [ ] 3.3 Run `cd mobile/gui_shell && flutter analyze && flutter test`
- [ ] 3.4 Run `openspec validate refactor-15-shared-flutter-shell-core --strict --no-interactive`
