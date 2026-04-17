# Change: [35] Add mobile user provider templates

## Why
The current mobile `Providers` flow only supports two template sources:
immutable shipped templates and blank provider-family creation.
That is enough for curated bootstrap paths, but it does not let operators save
their own reusable provider setups as future starting points.

Forcing users to duplicate saved providers or re-enter settings manually mixes
two different concepts:

- a saved provider record that can be applied to Profiles right now
- a template that seeds a future provider draft without becoming the active
  reusable provider itself

Provider families should stay app-owned taxonomy.
User templates should become the operator-owned bootstrap layer on top of that
taxonomy.

## Sequence
- Order: `35`
- Depends on: `add-34-mobile-provider-workspace-list-first`
- Unblocks: operator-curated provider bootstrap flows, explicit template
  management, and a clean answer to "how do I create or edit templates?"

## What Changes
- Introduce shell-owned mobile user templates as a separate local entity from
  saved managed provider records.
- Allow operators to create, edit, delete, and use user templates without
  making provider families user-editable.
- Keep shipped templates available as read-only curated seeds and separate them
  from `My templates` in the mobile create flow.
- Make template use seed a new managed provider draft by snapshot copy rather
  than by live binding.
- Add a dedicated mobile template editing path, seeded either from an existing
  provider draft/record or from an existing user template.

## Impact
- Affected specs: `mobile-gui-client`
- Affected code:
  - `mobile/gui_shell/lib/src/control/mobile_shell_controller.dart`
  - `mobile/gui_shell/lib/src/control/mobile_shell_state_store.dart`
  - `mobile/gui_shell/lib/src/ui/dashboard_page.dart`
  - `mobile/gui_shell/lib/src/ui/provider_config_editor.dart`
  - `mobile/gui_shell/test/widget_test.dart`
  - `packages/flutter_shell_core/lib/src/control/control_plane_models.dart`
  - `packages/flutter_shell_core/lib/src/control/profile_draft.dart`
