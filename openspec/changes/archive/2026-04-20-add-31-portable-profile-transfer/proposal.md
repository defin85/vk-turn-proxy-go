# Change: [31] Add portable profile transfer across desktop and mobile shells

## Why
Desktop and mobile shells now persist only redacted local shell state by
design. That keeps ordinary persistence safer, but it leaves a product gap:

- reinstalling the app or shell loses the working invite/link input needed to
  reconstruct some profiles
- moving a profile from desktop to mobile still falls back to manual re-entry,
  copy-paste, or ad hoc debugging steps
- the existing `export_handoff` flow is for resolved runtime handoff, not for
  restoring a saved shell profile

The product now needs one explicit, operator-driven profile transfer mechanism
that works across desktop and mobile without weakening the existing redaction
rules for ordinary shell persistence.

## Sequence
- Order: `31`
- Depends on: `add-29-mobile-vpn-product-shell`,
  `add-30-desktop-vpn-workbench-shell`
- Unblocks: practical desktop-to-mobile and mobile-to-desktop profile transfer,
  reinstall recovery, and product-grade QR handoff for saved profiles

## What Changes
- Add one shared, versioned portable-profile envelope in
  `packages/flutter_shell_core` for explicit shell-to-shell transfer.
- Keep portable profile transfer separate from `export_handoff` and from
  ordinary redacted shell persistence.
- Require desktop to support explicit profile export/import with file or text
  transfer plus QR rendering for cross-device handoff.
- Require mobile to support explicit profile export/import with platform-native
  share or file flows plus QR scan/render paths, while keeping Android and iOS
  adapters app-local over the same shared envelope.
- Preserve enough shell-local metadata to restore managed-provider-backed
  profiles without trusting source-local ids on the destination shell.
- Keep user provider templates out of the portable-profile envelope because
  templates seed provider authoring flows but do not satisfy a saved profile's
  runtime dependency on a managed provider record.
- Keep the first shipped import path append-only: imported profiles and managed
  provider snapshots become new local records instead of an in-place
  replacement workflow.
- Keep secret-bearing profile transfer explicit, operator-reviewed, and
  fail-closed instead of treating it like background state sync.

## Impact
- Affected specs: `flutter-shell-workspace`, `desktop-gui-client`,
  `mobile-gui-client`
- Affected code: `packages/flutter_shell_core`, desktop and mobile shell
  controllers/state models, profile workspace UI, platform adapters for file,
  share, clipboard, and QR surfaces, plus related shell docs and tests
