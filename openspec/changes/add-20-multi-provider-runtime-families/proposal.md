# Change: [20] Add multi-provider runtime families

## Why
The current provider and shell model assumes that successful provider
resolution always ends in transport-ready TURN credentials plus optional
`generic-turn://...` export semantics.

That is already too narrow for the next provider wave.

Live research on April 11, 2026 showed two materially different provider
shapes:

- `stream.wb.ru` behaves like a conference provider with room-level signaling,
  room-scoped media tokens, and a provider-owned conference runtime surface
- `lk.smarthome.rt.ru` behaves like a camera/device portal with stream tokens,
  player/archive controls, and a media-player pipeline rather than an
  invite-first conference flow

If the repository keeps treating every provider result as "just another TURN
link", the host API and GUI shells will either hard-code provider-specific UX
or lie about what a resolved provider result can actually do.

## Sequence
- Order: `20`
- Depends on: `add-01-client-control-plane`, `add-02-desktop-gui-shell`,
  `add-03-mobile-gui-shell`, `add-17-provider-resolution-handoff`
- Unblocks: follow-on provider integrations beyond VK, including
  conference-style and camera-style product surfaces

## What Changes
- Add one platform-neutral provider catalog and artifact model that can
  describe more than one runtime family.
- Advertise that multi-provider catalog/artifact contract through an explicit
  host capability so updated shells fail closed against older
  handoff-only hosts instead of guessing compatibility from the old surface.
- Roll the new contract out additively for first-party migration, then remove
  the old `provider-resolution-handoff` path from the shipped add-20 surface.
- Introduce typed provider descriptors so shells can render provider entry
  flows from host-reported metadata rather than hard-coded provider strings,
  including provider auth posture and browser-continuation policy.
- Generalize resolution output from a generic-turn-only handoff model into a
  typed artifact contract with explicit artifact families such as
  `generic_turn`, `conference_room`, and `camera_stream`.
- Make provider auth requirements and browser constraints first-class contract
  fields so auth-bound providers and anti-bot-sensitive providers do not get
  flattened into a fake "paste link and continue" workflow.
- Keep `generic-turn://...` export as an explicit capability of the
  `generic_turn` artifact family rather than the universal output of every
  provider.
- Define capability-gated same-device actions so the host and shells can offer
  only the actions that are actually supported for a resolved artifact family.
- Keep those artifact actions machine-readable and stable across platforms so
  desktop/mobile shells can localize presentation without reintroducing
  provider-name branching.
- Move provider entry from an untyped `provider + link` assumption to a typed
  input envelope and remove the legacy untyped request bridge from the shipped
  add-20 surface.
- Keep provider tokens and other secret-bearing fields redacted in ordinary
  reads regardless of artifact family.

## Impact
- Affected specs: `provider-runtime-artifacts` (new), `client-control-plane`,
  `desktop-gui-client`, `mobile-gui-client`
- Affected code: `internal/provider`, `pkg/clientcontrol`, `cmd/clientd`,
  desktop and mobile shell control-plane models, provider-facing docs and
  workflow docs
