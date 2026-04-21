# Change: [50] Add flow-6 provider expansion camera stream actions

## Why
The current live contract already names `camera_stream` as a distinct artifact
family, but it does not yet commit the first ordinary action surface for that
family.

That gap blocks honest camera-style providers. Without one typed action
contract, the first camera provider rollout would either flatten camera access
into a fake conference or tunnel model, or force provider-specific raw payload
handling back into the shells.

Flow-6 needs one generic camera-stream action surface before a provider such as
`smarthome` can be added honestly.

## Sequence
- Order: `50`
- Depends on: `add-20-multi-provider-runtime-families`,
  `add-48-flow-6-provider-expansion-shipping-gates`
- Unblocks: `add-52-flow-6-provider-expansion-smarthome-provider`

## What Changes
- Add a `camera-stream-actions` capability that defines the typed ordinary
  summary and machine-readable post-resolution actions for `camera_stream`
  artifacts.
- Standardize the first camera-stream action surface around explicit
  shell-external navigation such as `open_camera` and optional `open_archive`.
- Define how desktop and mobile shells present camera artifacts without
  pretending that the tunnel runtime or a local media executor already exists.
- Keep same-device playback execution out of scope until a later change adds a
  real family-specific executor.

## Impact
- Affected specs: `camera-stream-actions` (new)
- Affected code: `pkg/clientcontrol`, host resolution/event models, desktop and
  mobile shell action surfaces, provider-facing docs

## Assumptions
- The first committed camera-stream action is `open_camera`, with
  `open_archive` optional when the provider exposes a real archive target.
- The product should not claim local camera playback, conference attach, or
  tunnel semantics for `camera_stream` artifacts in this slice.
- Provider-specific player or stream tokens must remain redacted in ordinary
  reads.
