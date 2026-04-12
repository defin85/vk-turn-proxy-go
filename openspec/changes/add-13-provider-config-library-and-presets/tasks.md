## 1. Control Plane
- [x] 1.1 Add provider-config record models plus list/create/update/delete
      control-plane operations with descriptor-based validation.
- [x] 1.2 Reject `writeOnly`, `ephemeral`, undeclared, or provider-mismatched
      settings from provider-config CRUD and surface typed failures.
- [x] 1.3 Keep saved profiles snapshot-based when a shell applies a provider
      config to a draft or profile.

## 2. Shared Shell Core
- [x] 2.1 Add shared provider-config models/controllers for desktop and mobile.
- [x] 2.2 Add a shared preset catalog for `VK`, `WB Stream`, and
      `RTK Smarthome`, keyed to stable provider ids and availability-gated by
      host descriptors.
- [x] 2.3 Reuse the descriptor-driven provider-settings renderer for
      provider-config CRUD surfaces without mixing runtime defaults back in.

## 3. Desktop GUI
- [x] 3.1 Add explicit `Presets`, `Provider configs`, and `Profiles` entry
      points in the desktop workflow IA.
- [x] 3.2 Add desktop provider-config add/edit/delete/apply flows.
- [x] 3.3 Add desktop widget tests for preset availability, provider-config
      CRUD, unavailable descriptor state, and snapshot-based profile apply.

## 4. Mobile GUI
- [x] 4.1 Add mobile preset and provider-config workflow surfaces that fit the
      workflow-first navigation model.
- [x] 4.2 Add mobile provider-config add/edit/delete/apply flows.
- [x] 4.3 Add mobile widget tests for preset availability, provider-config
      CRUD, unavailable descriptor state, and snapshot-based profile apply.

## 5. Validation
- [x] 5.1 Run the smallest relevant Go tests for `pkg/clientcontrol` and any
      added provider-config storage/validation paths.
- [x] 5.2 Run `flutter analyze && flutter test` for
      `packages/flutter_shell_core`, `desktop/gui_shell`, and
      `mobile/gui_shell`.
- [x] 5.3 Run
      `openspec validate add-13-provider-config-library-and-presets --strict --no-interactive`.
