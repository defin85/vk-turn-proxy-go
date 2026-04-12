# Change: [13] Add provider config library and preset profile bootstrap

## Why
`add-21-provider-defined-entry-fields` made provider settings descriptor-driven,
but it intentionally kept those settings embedded inside one saved profile or
one in-memory draft.

That is no longer enough for the next shell UX slice:

- operators need reusable provider-specific configuration sets with explicit
  add/edit/delete flows
- shells need a faster bootstrap path into the main provider families instead
  of starting every draft from an empty provider selector
- upcoming providers such as `WB Stream` and `RTK Smarthome` need honest UI
  entry points before their runtime adapters are fully productized

If the repository keeps provider settings trapped inside individual profiles,
the shells will either duplicate the same fields across many profiles or start
smuggling reusable provider meaning back into runtime defaults.

## Sequence
- Order: `13`
- Depends on: `add-20-multi-provider-runtime-families`,
  `add-21-provider-defined-entry-fields`,
  `refactor-12-flutter-workspace-shell-core`,
  `refactor-23-desktop-gui-workflow-first-layout`,
  `refactor-24-mobile-gui-workflow-first-navigation`
- Unblocks: future `wb-stream` and `smarthome` operator rollouts with reusable
  provider-owned configuration instead of one-off shell drafts

## What Changes
- Add a first-class provider-config library to the local control plane and both
  GUI shells for reusable non-secret provider settings keyed to one provider.
- Keep saved profiles self-contained: applying a provider config copies its
  retained settings into the active draft/profile instead of creating a hidden
  live reference.
- Add a shared preset profile catalog for `VK`, `WB Stream`, and
  `RTK Smarthome` so desktop and mobile can bootstrap a new draft from a known
  provider family with curated copy and seed values.
- Rework desktop and mobile workflow IA so `Presets`, `Provider configs`, and
  `Profiles` are distinct operator surfaces instead of one overloaded editor.

## Impact
- Affected specs: `client-control-plane`, `desktop-gui-client`,
  `mobile-gui-client`
- Affected code: `pkg/clientcontrol`, desktop/mobile shell controllers and
  editors, local shell state stores, `packages/flutter_shell_core`

## Assumptions
- `WB` maps to the future `wb-stream` provider family already referenced by
  `add-20-multi-provider-runtime-families`.
- `РТК` maps to the future `smarthome` provider family referenced in the same
  add-20 design.
- Presets are UI bootstrap assets, not proof that the current host build can
  resolve those providers. Shells must gate preset availability on the
  provider descriptors actually advertised by the connected host.
