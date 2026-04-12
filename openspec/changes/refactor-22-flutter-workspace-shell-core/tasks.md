## 1. Workspace topology
- [ ] 1.1 Add a repository-root Flutter/Dart workspace with an explicit member list for `desktop/gui_shell`, `mobile/gui_shell`, and `packages/flutter_shell_core`
- [ ] 1.2 Convert the shell app packages to workspace resolution and document the canonical repo-root dependency resolution command
- [ ] 1.3 Define and enforce which lockfiles and generated resolution artifacts remain authoritative after workspace migration, including removal of app-local resolution artifacts as script or CI inputs

## 2. Shared shell core package
- [ ] 2.1 Create `packages/flutter_shell_core` as a pure Flutter package
- [ ] 2.2 Move platform-neutral shell leaf modules into the shared core: control-plane models, control-plane client logic, profile draft shaping, and build identity helpers
- [ ] 2.3 Refactor `desktop/gui_shell` to consume the shared core while keeping sidecar supervision and file-backed desktop state local
- [ ] 2.4 Refactor `mobile/gui_shell` to consume the shared core while keeping native bridge resolution, secure storage, lifecycle handling, and browser handoff local
- [ ] 2.5 Extract reusable UI primitives only when they remain free of platform-specific runtime assumptions and plugin ownership

## 3. Repo-owned wiring
- [ ] 3.1 Update shell version-sync, dependency, build, and packaging scripts for the workspace topology
- [ ] 3.2 Update shell docs and CI verification to include repo-root workspace resolution as a public developer workflow plus both app packages
- [ ] 3.3 Update operator-facing shell build workflow docs/spec deltas when commands or prerequisites change
- [ ] 3.4 Remove or rewrite app-local `flutter pub get` guidance and script assumptions anywhere repository-root workspace resolution is now authoritative
- [ ] 3.5 Keep archive/promotion readiness explicit for both `flutter-shell-workspace` and `native-build-workflows`, including creation of current specs under `openspec/specs/` when the change is archived

## 4. Verification
- [ ] 4.1 Run `dart pub get`
- [ ] 4.2 Run `dart pub workspace list`
- [ ] 4.3 Run `cd packages/flutter_shell_core && flutter analyze && flutter test`
- [ ] 4.4 Run `cd desktop/gui_shell && flutter analyze && flutter test`
- [ ] 4.5 Run `cd mobile/gui_shell && flutter analyze && flutter test`
- [ ] 4.6 Run `openspec validate refactor-22-flutter-workspace-shell-core --strict --no-interactive`
