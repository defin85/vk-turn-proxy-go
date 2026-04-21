# Change: [54] Add flow-7 Telemost provider contract

## Why
After `add-53`, the repository can describe what Telemost is not. It still
lacks the positive contract for what a reviewed Telemost provider slice would
look like inside the host and shells.

The current repo-wide conference contract is generic enough to avoid fake TURN
semantics, but it does not yet define a Telemost-specific descriptor,
resolution-entry posture, or ordinary resolved artifact shape.

Flow-7 therefore needs one provider contract that turns Telemost from a legacy
matrix note into an explicit future provider surface without overclaiming
same-device execution.

## Sequence
- Order: `54`
- Depends on: `add-48-flow-6-provider-expansion-shipping-gates`,
  `add-49-flow-6-provider-expansion-conference-room-actions`,
  `add-53-flow-7-telemost-provider-readiness`
- Unblocks: `add-55-flow-7-telemost-video-frame-carrier`,
  `add-56-flow-7-telemost-release-verification`

## What Changes
- Add a `telemost-provider` capability that defines the descriptor,
  resolution-entry contract, and ordinary resolved artifact shape for
  `yandex-telemost`.
- Map successful Telemost resolution to the `conference_room` artifact family
  plus the committed `open_room` action surface.
- Keep same-device Telemost attach or runtime execution separately gated by a
  later carrier slice.
- Require explicit auth and browser posture so shells do not infer support from
  provider name or from historical behavior.

## Impact
- Affected specs: `telemost-provider` (new)
- Affected code: future `internal/provider/yandextelemost`,
  `pkg/clientcontrol`, desktop/mobile provider entry flows, provider docs

## Assumptions
- The first reviewed Telemost provider slice targets `conference_room`
  semantics rather than `generic_turn`.
- The first ordinary operator action is `open_room`.
- Embedded-browser, guest-only, or same-device attach support must remain
  explicit instead of assumed.
