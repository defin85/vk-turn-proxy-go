## 1. Product contract

- [x] 1.1 Define provider sources/contours and VPN transport profiles as
      independent operator-facing catalogs.
- [x] 1.2 Define the compatibility matrix that combines provider artifact,
      carrier family, engine family, host adapter, and required profile kind.
- [x] 1.3 Keep provider records from owning VPN transport secrets or implicit
      transport-profile defaults.
- [x] 1.4 Keep VPN transport profiles from owning provider credentials,
      signaling state, or provider-source defaults.

## 2. Shell UX

- [x] 2.1 Add desktop requirements for separate Provider Sources and VPN
      Transport Profiles workspaces plus a route/plan surface that combines
      the selected axes.
- [x] 2.2 Add mobile requirements for the same separated Provider Sources and
      VPN Transport Profiles destinations.
- [x] 2.3 Show unsupported, setup-needed, degraded, and missing-evidence states
      for combinations without silently substituting either axis.
- [x] 2.4 Preserve Home as the primary VPN start/stop owner while provider and
      transport workspaces manage selection and setup.

## 3. Control-plane and runtime behavior

- [x] 3.1 Extend control-plane contract so startup intent can carry explicit
      provider-source/resolution and transport-profile references.
- [x] 3.2 Extend runtime execution planning so plan support reports the selected
      source/profile compatibility reason.
- [x] 3.3 Ensure unsupported combinations fail closed before provider or native
      adapter startup claims readiness.

## 4. Validation

- [x] 4.1 Run
      `openspec validate add-77-independent-provider-and-transport-selection --strict --no-interactive`.
- [x] 4.2 Run `openspec validate --all --strict --no-interactive`.
- [x] 4.3 Run `git diff --check`.
- [x] 4.4 Run desktop shell controller and widget regression coverage:
      `flutter test test/desktop_shell_controller_test.dart`,
      `flutter test test/widget_test.dart`,
      `flutter test test/locale_chrome_test.dart`.
- [x] 4.5 Run mobile shell controller, bridge, and widget regression coverage:
      `flutter test test/mobile_shell_controller_test.dart`,
      `flutter test test/mobile_host_bridge_test.dart`,
      `flutter test test/widget_test.dart`.
- [x] 4.6 Run shared Flutter shell core coverage and static checks:
      `flutter test test/control_plane_client_test.dart`,
      `dart analyze packages/flutter_shell_core`,
      `flutter analyze` in `desktop/gui_shell` and `mobile/gui_shell`.
