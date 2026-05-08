# Change: [82] Add portable VPN transport profile transfer

## Why

RelayDock already has explicit portable transfer for saved shell profiles, but
that workflow stops at the shell snapshot boundary.
Live tablet inspection on May 8, 2026 confirmed the gap in the shipped
product:

- `VPS copy` appears in the `Profiles` workspace and exposes `Export saved
  profile`
- `RelayDock VPS WireGuard 92.63.105.2` appears in `VPN transport profiles`
  and exposes only create/import/select/edit/validate/forget style actions
- moving the saved profile alone to another device does not move the required
  host-owned VPN transport profile, so native-VPN startup still fails closed
  until the destination host recreates or imports matching transport material

This gap is also intentional in the current contract.
`vpn-transport-profile-store` explicitly excludes secret-bearing material from
ordinary backup, migration, or sync unless a later reviewed encrypted export
contract is defined.
That later contract is now needed as a first-class product workflow.

## Sequence

- Order: `82`
- Depends on:
  `add-73-vpn-transport-profile-store`,
  `add-74-vpn-transport-profile-editor`,
  `add-76-relaydock-schema-driven-vpn-transport-profiles`,
  archived `add-31-portable-profile-transfer`
- Unblocks: explicit desktop/mobile cross-device reuse of VPN transport
  profiles without weakening the host-owned secret boundary

## What Changes

- Extend the VPN transport profile store contract with an explicit encrypted
  portable transfer workflow for secret-bearing transport profiles.
- Keep transport-profile transfer host-driven, operator-reviewed, and separate
  from ordinary persistence, platform backup/sync, and saved-profile portable
  transfer.
- Advertise portable transfer through a dedicated capability block plus a
  per-profile `export_portable` action instead of overloading ordinary import
  adapters or generic edit actions.
- Extend the client control plane with typed export, preview/import, and
  confirmation actions for encrypted portable transport-profile envelopes.
- Add desktop and mobile UI affordances to export and import VPN transport
  profiles from the transport-profile manager and setup surfaces.
- Include QR as part of the first shipped encrypted-envelope path: desktop and
  mobile can render QR when the encrypted payload fits bounds, and mobile can
  scan that QR for import.
- Lock the first reviewed crypto profile for portable transport-profile
  envelopes instead of leaving passphrase-based encryption underspecified.
- Keep the first shipped transport-profile transfer slice separate from saved
  profile transfer instead of bundling both record types into one opaque
  workspace blob.
- Preserve fail-closed startup: a transferred saved profile still cannot start
  native VPN on the destination host until a compatible VPN transport profile
  is imported and selected there.
- Define first-slice preview outcomes up front so duplicate, blocked, and
  display-name-collision cases do not get improvised later in UI code.

## Impact

- Affected specs:
  `vpn-transport-profile-store`,
  `client-control-plane`,
  `mobile-gui-client`,
  `desktop-gui-client`
- Affected code:
  `pkg/clientcontrol`,
  transport-profile store/export logic,
  `packages/flutter_shell_core`,
  `mobile/gui_shell`,
  `desktop/gui_shell`,
  host adapters that advertise transport-profile lifecycle actions

## Assumptions

- The first reviewed cross-device transport-profile workflow should be
  encrypted and explicit, not a side effect of ordinary app backup or
  persistence.
- The shell may carry opaque encrypted envelopes across share, file, text, or
  QR paths, but the host remains the source of truth for encryption,
  decryption, validation, storage, and compatibility checks.
- The first shipped transport-profile transfer slice includes QR as a supported
  cross-device path, subject to explicit payload-size bounds.
- This change does not yet bundle saved profiles and VPN transport profiles
  into one combined export unit.
