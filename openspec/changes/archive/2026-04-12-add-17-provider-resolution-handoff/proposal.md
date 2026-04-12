# Change: [17] Add provider resolution handoff

## Why
The repository can already resolve live provider inputs into transport-ready
TURN credentials, but only the CLI `probe` path can emit a ready-to-paste
`generic-turn://...` handoff link.

That leaves an important product gap:

- desktop and mobile shells do not share a typed way to obtain a handoff-ready
  `generic-turn` link
- the local host cannot expose provider resolution as a first-class artifact
  separate from runtime sessions
- the desktop product path cannot be validated directly from a live invite
  without dropping back to CLI-only tooling

Without a shared handoff contract, the repository risks shipping three
different workflows for the same underlying provider result:
CLI export, desktop session startup, and mobile/cross-device handoff.

## Sequence
- Order: `17`
- Depends on: `add-01-client-control-plane`, `add-02-desktop-gui-shell`,
  `add-03-mobile-gui-shell`
- Unblocks: `add-10-vk-invite-user-workflow` and future cross-device invite
  handoff work

## What Changes
- Add one platform-neutral provider-resolution handoff capability to the local
  host contract.
- Define a typed resolution resource that is separate from runtime sessions and
  can move through `starting`, `challenge_required`, `resolved`, `failed`,
  `cancelled`, or `expired` states.
- Allow explicit export of a short-lived `generic-turn://...` handoff link only
  after provider resolution reaches transport-ready credentials and the host can
  attach authoritative expiry information, whether that expiry is surfaced
  directly by the provider result or derived through a committed
  repository-owned provider-specific parser contract.
- Allow same-device materialization of a successful resolution into the normal
  product runtime path from explicit non-secret runtime defaults without
  requiring manual secret copy steps or persistence of a secret-bearing saved
  profile.
- Keep raw TURN credentials redacted in ordinary state reads, events,
  diagnostics, and persisted shell state unless the operator explicitly chooses
  an export/share action.

## Impact
- Affected specs: `provider-resolution-handoff` (new)
- Affected code: `pkg/clientcontrol`, `cmd/clientd`, desktop and mobile shell
  control-plane integrations, any shared shell-core abstractions, `cmd/probe`
  export alignment, docs for desktop/mobile/operator workflows
