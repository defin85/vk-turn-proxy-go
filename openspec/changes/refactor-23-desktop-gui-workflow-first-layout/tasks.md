## 1. Layout contract
- [x] 1.1 Replace the fragmented desktop top chrome with one consolidated
      operational header for host, notices, and platform-tunnel summary.
- [x] 1.2 Separate saved-profile navigation from the active profile editor and
      primary workflow actions.
- [x] 1.3 Rebalance the main desktop canvas so empty resolutions, sessions, and
      event diagnostics do not dominate the initial layout.

## 2. Shell implementation
- [x] 2.1 Refactor `DashboardPage` composition to support the new desktop
      information architecture without changing control-plane behavior.
- [x] 2.2 Refactor `ProfileEditorPanel` so profile browsing, editing, and
      advanced/secondary content are clearly separated.
- [x] 2.3 Move event stream and detailed platform-tunnel/support diagnostics
      into a secondary desktop surface with explicit reveal behavior.

## 3. Verification
- [x] 3.1 Add or update desktop widget coverage for the consolidated header,
      initial empty state, profile switching, and selected live context.
- [x] 3.2 Run `cd desktop/gui_shell && flutter analyze && flutter test`.
- [x] 3.3 Run `openspec validate refactor-23-desktop-gui-workflow-first-layout --strict --no-interactive`.
