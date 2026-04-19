# Change: [39] Unify mobile profile and provider actions

## Why
The current mobile shell splits entity actions across too many surfaces.
`Profiles` is list-first, but import/export and several secondary actions live
inside the profile editor. `Providers` is also list-first, but most reusable
actions still live inside provider detail, while templates remain partially
hidden behind the create-provider flow.

That leaves the operator with three problems:

- core actions such as copy, import, and export are not discoverable from the
  entity roots where users look first
- `Profiles` and `Providers` behave differently for equivalent record actions
- the UI does not expose a clear "record list -> actions -> detail" model

The shell already has the underlying controller and portable-transfer
capabilities for most of this behavior.
The missing piece is a stable action taxonomy and one explicit gap: first-class
copy semantics for profiles, managed providers, and user templates.

## Sequence
- Order: `39`
- Depends on:
  - `add-31-portable-profile-transfer`
  - `add-34-mobile-provider-workspace-list-first`
  - `add-35-mobile-user-provider-templates`
  - `add-38-mobile-surface-taxonomy`
- Unblocks:
  - consistent mobile CRUD and reuse ergonomics
  - clearer operator mental model for profiles vs providers
  - later desktop alignment on the same action contract

## What Changes
- Define one mobile action model for `Profiles` and `Providers` around root
  command surfaces plus detail editors.
- Add explicit `Copy` actions for saved profiles, saved managed providers, and
  user templates.
- Move profile import/export entry points to the main `Profiles` workflow
  surface instead of hiding them behind profile creation or editor disclosure.
- Promote templates to a first-class `Providers` workflow surface instead of
  leaving them as a mostly create-only branch.
- Keep editor footers focused on commit actions and move secondary entity
  actions out of the footer.
- Separate opening a profile for detail/editing from choosing the profile that
  `Home` treats as current.

## Impact
- Affected specs: `mobile-gui-client`
- Affected code:
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/profile_editor.dart`
  - `mobile/gui_shell/lib/src/ui/provider_config_editor.dart`
  - `mobile/gui_shell/lib/src/control/mobile_shell_controller.dart`
  - `mobile/gui_shell/lib/src/control/mobile_shell_state_store.dart`
  - `mobile/gui_shell/test/widget_test.dart`
  - `mobile/gui_shell/test/mobile_shell_controller_test.dart`
  - `packages/flutter_shell_i18n/lib/src/i18n/en.arb`
  - `packages/flutter_shell_i18n/lib/src/i18n/ru.arb`
