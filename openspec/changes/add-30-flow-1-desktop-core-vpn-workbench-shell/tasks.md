## 1. Desktop information architecture
- [x] 1.1 Define the desktop destination model around `Home`, `Profiles`,
      `Routing`, support-oriented `Activity` and `Diagnostics`, and `Settings`.
- [x] 1.2 Rework the shell layout so one dominant task canvas owns the active
      route while persistent left navigation remains stable across desktop
      widths.
- [x] 1.3 Define resize rules for compact desktop widths, medium widths, and
      wide workbench layouts.

## 2. Desktop workbench surfaces
- [x] 2.1 Reduce desktop home to a concise overview and command surface.
- [x] 2.2 Move profile management into a dedicated dense desktop workflow such
      as list/detail or workbench editing.
- [x] 2.3 Move routing into its own dedicated desktop work surface instead of a
      stretched or hidden mobile-derived flow.

## 3. Live work and support surfaces
- [x] 3.1 Move logs, live connections, or similar runtime detail into a bottom
      ribbon or explicit secondary support pane.
- [x] 3.2 Keep diagnostics and activity quickly reachable without letting them
      reclaim the main canvas by default.
- [x] 3.3 Verify keyboard traversal, inspector behavior, and route persistence
      across desktop resize changes.

## 4. Validation
- [x] 4.1 Update desktop widget, navigation, and interaction tests for the new
      workbench shell.
- [x] 4.2 Cross-check the resulting shell against desktop-first workbench
      expectations instead of stretched mobile layouts.
- [x] 4.3 Run `openspec validate add-30-flow-1-desktop-core-vpn-workbench-shell --strict
      --no-interactive`.
