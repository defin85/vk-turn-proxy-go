# Change: [48] Add flow-6 provider expansion shipping gates

## Why
The repository already contains historical research and shell-bootstrap traces
for future providers such as `WB Stream` and `RTK Smarthome`, but the current
live product truth intentionally ships only `vk` and `generic-turn`.

That split is correct, but it is currently enforced by convention rather than
by one explicit rollout contract. Without a dedicated shipping gate, future
provider work can drift into the wrong state:

- presets or templates can start looking like product support
- provider descriptors can appear before the corresponding shell/runtime
  surfaces are ready
- one platform can look "done" while the shared supported-provider catalog
  still lies about cross-platform readiness

Flow-6 needs one explicit first change that defines when a researched provider
family is allowed to become an operator-facing shipped provider.

## Sequence
- Order: `48`
- Depends on: `add-20-multi-provider-runtime-families`,
  `update-23-app-owned-provider-catalog`
- Unblocks: `add-49-flow-6-provider-expansion-conference-room-actions`,
  `add-50-flow-6-provider-expansion-camera-stream-actions`,
  `add-51-flow-6-provider-expansion-wb-stream-provider`,
  `add-52-flow-6-provider-expansion-smarthome-provider`

## What Changes
- Add a new `supported-provider-rollout` capability that defines the product
  gate for promoting a provider family from researched or planned into the
  shipped app-owned provider catalog.
- Require a provider-specific contract plus matching artifact-family action
  surfaces before the repository can claim that a new provider family is
  operator-facing support.
- Keep presets, templates, and research artifacts explicitly non-authoritative
  for shipped support status.
- Keep partial rollout fail-closed: a provider family stays out of the
  ordinary shipped catalog until the committed host and shell surfaces are
  ready.

## Impact
- Affected specs: `supported-provider-rollout` (new)
- Affected code: shared shell catalog code in `packages/flutter_shell_core`,
  host descriptor exposure in `pkg/clientcontrol`, desktop/mobile provider
  workspaces, provider-facing docs

## Assumptions
- Flow-6 is about future providers beyond `vk` and `generic-turn`, with the
  first two concrete candidates being `wb-stream` and `smarthome`.
- A provider family is not "shipped" just because archived OpenSpec work,
  disabled presets, or test-only fixtures mention it.
- Release verification for a new provider family may land as a later follow-up,
  but ordinary operator-facing support must still stay fail-closed until the
  committed gate is satisfied.
