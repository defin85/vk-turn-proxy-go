# Change: [23] Update shell provider workflow around an app-owned provider catalog

## Why
The current `Provider configs` workflow solved a different problem than the
operator model we actually want.

Today the shells treat host-reported descriptors as the primary provider
catalog, and the separate `Provider configs` surface only appears for
providers that advertise a reusable `provider_settings_schema`. That makes the
operator-facing provider list incomplete for shipped providers such as
`Generic TURN` and `VK Calls`, and it turns `Presets` into a fake provider
taxonomy instead of what they should be: seed variations for new provider
records.

The intended workflow is different:

- the application owns one honest list of supported providers
- those providers can expose editable parameters
- presets are variations for creating new provider records
- connection profiles use either a managed provider record or a custom path

## What Changes
- Replace the shell-primary `Provider configs` model with an app-owned managed
  provider catalog shared by desktop and mobile.
- Keep host-reported provider descriptors as a runtime availability and
  validation overlay instead of the only operator-facing provider taxonomy.
- Keep host-managed `provider_configs` surfaces compatibility-only during the
  rollout; shells must stop requiring them for ordinary provider workflows.
- Reframe presets as seed templates for new managed provider records rather
  than as standalone pseudo-providers.
- Let profile drafts start from either a managed provider record or a custom
  provider path while keeping saved profiles and session starts snapshot-based.
- Stop treating host-managed provider-config CRUD as the normative shell
  workflow.

## Impact
- Affected specs: `client-control-plane`, `desktop-gui-client`,
  `mobile-gui-client`, `flutter-shell-workspace`
- Affected code: `pkg/clientcontrol`, `packages/flutter_shell_core`,
  `desktop/gui_shell`, `mobile/gui_shell`

## Assumptions
- The initial app-owned supported-provider catalog will include the currently
  shipped supported providers such as `generic-turn` and `vk`.
- The first shipped managed-provider slice may include supported providers such
  as `generic-turn` and `vk` even when they expose zero or near-zero reusable
  managed fields.
- Future providers such as `wb-stream` and `smarthome` should not appear in
  the operator-facing managed-provider catalog or preset catalog until the app
  intentionally ships them as supported providers.
- Managed provider records remain reusable non-secret shell state; prompt-only
  values, invite/session links, and static credentials remain profile-local or
  custom-entry concerns unless a later change introduces a secure managed-input
  model explicitly.
- When a saved profile originated from a managed provider, reopening that
  profile in the shell should restore managed-provider mode instead of
  degrading it into an indistinguishable custom profile edit surface.
- Profiles and runtime starts will continue to materialize down to ordinary
  `provider`, `link`, and `provider_settings` snapshots at the control-plane
  boundary rather than sending a managed-provider identifier to the host.
