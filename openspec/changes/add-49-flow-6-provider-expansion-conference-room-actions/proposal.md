# Change: [49] Add flow-6 provider expansion conference room actions

## Why
The current live contract already distinguishes the `conference_room` artifact
family from `generic_turn`, but it still stops at a high level.

That is enough for architectural truthfulness, but not enough for a real
provider rollout. The first conference-style provider in flow-6 must not force
the product back into raw provider payload parsing or fake tunnel semantics.

Before the repository can ship a conference provider such as `wb-stream`, it
needs one committed host-and-shell contract for what a resolved conference room
artifact actually exposes and what operators can do with it.

## Sequence
- Order: `49`
- Depends on: `add-20-multi-provider-runtime-families`,
  `add-48-flow-6-provider-expansion-shipping-gates`
- Unblocks: `add-51-flow-6-provider-expansion-wb-stream-provider`

## What Changes
- Add a `conference-room-actions` capability that defines the typed ordinary
  summary and machine-readable post-resolution actions for
  `conference_room` artifacts.
- Standardize the first conference-room action surface around explicit
  shell-external room opening instead of fake same-device runtime claims.
- Define how desktop and mobile shells present conference-room artifacts and
  their actions without reintroducing provider-name branching.
- Keep same-device conference execution out of scope until a later change adds
  a real executor.

## Impact
- Affected specs: `conference-room-actions` (new)
- Affected code: `pkg/clientcontrol`, host event/resolution models, desktop and
  mobile shell resolution and action surfaces, provider-facing docs

## Assumptions
- The first committed conference-room action is `open_room`.
- The product should not promise local conference execution, media attach, or
  generic-turn export for conference artifacts in this slice.
- Provider-specific conference metadata must stay redacted or non-secret in
  ordinary reads.
