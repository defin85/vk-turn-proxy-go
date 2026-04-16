## Context

The shells already have two different profile-related data paths:

- ordinary local shell persistence, which deliberately redacts invite links,
  handoff URLs, and other secret-bearing profile inputs
- explicit `export_handoff`, which is a runtime-resolution action for a
  resolved artifact and not a reusable saved-profile transfer mechanism

That separation is correct, but it leaves no product-grade way to move a saved
profile between shells or recover it after reinstall without manual re-entry.

The current platform split also matters:

- desktop persists redacted shell state in a local JSON file
- mobile persists redacted state in preferences and keeps a fail-closed guard
  around older secure-state migrations
- both shells now share `packages/flutter_shell_core` for platform-neutral
  models, but platform adapters still live app-locally

This change should add one explicit profile-transfer path without weakening the
existing persistence and handoff boundaries.

## Goals / Non-Goals

- Goals:
  - Let operators move one saved profile between desktop and mobile shells
    without manual re-entry.
  - Provide QR as a first-class cross-device transport where the payload fits.
  - Preserve managed-provider vs custom-provider source mode across import.
  - Keep ordinary local persistence redacted and separate from portable export.
  - Keep import/export explicit and fail-closed.
- Non-Goals:
  - Do not add background sync, cloud sync, or account-bound profile sync.
  - Do not redefine host-side `profiles` or `export_handoff` semantics.
  - Do not require first-slice desktop camera scanning; desktop can start with
    file/text import plus QR rendering/export.
  - Do not turn one exported profile into a bulk library backup format in this
    first slice.

## Decisions

### Decision: Use one shared portable-profile envelope in shared shell core

`packages/flutter_shell_core` should own one versioned portable-profile
envelope and its import/export shaping rules. Desktop and mobile should consume
that same envelope instead of inventing platform-specific transfer JSON.

The envelope should carry:

- one saved profile snapshot
- enough shell-local source metadata to reopen the imported profile in managed
  or custom mode
- an inline managed-provider snapshot when that is required to preserve managed
  mode on the destination shell
- transfer metadata such as schema version and secret classification

### Decision: Keep profile transfer separate from runtime handoff export

Portable profile transfer is a shell-local operator workflow.
`export_handoff` remains a host/runtime action for resolved provider artifacts.

Neither path should masquerade as the other:

- importing a portable profile must not require a resolved runtime handoff
- exporting a runtime handoff must not silently become a saved-profile backup

### Decision: Preserve portability without trusting source-local ids

Source-local ids such as profile ids and managed-provider ids are not stable
cross-device identifiers.

Import should therefore treat incoming ids as advisory at most:

- destination shells should allocate fresh local ids by default
- import must not silently overwrite local profiles or managed providers based
  only on a matching source id
- if the imported profile references a managed provider, the destination shell
  should restore that relationship from the embedded snapshot rather than
  assuming the original managed-provider record already exists locally

### Decision: Secret-bearing transfer stays explicit and operator-reviewed

Ordinary local persistence remains redacted.
Portable transfer is the explicit escape hatch when the operator really wants a
working profile on another shell.

That means the portable envelope may contain secret-bearing provider input such
as invite links or `generic-turn://...` credentials when needed to reconstruct
the saved profile, but:

- shells must classify that payload as secret-bearing
- export/import UI must surface that sensitivity before share/save/render
- shells must not generate that envelope as background state sync
- diagnostics and ordinary shell persistence stay on the existing redacted path

### Decision: QR is one transport over the same envelope, not a second format

QR should encode the same shared portable-profile envelope used by file/text
transfer.

If the supported encoded payload is too large for the product's QR bounds, the
shell must fail closed for QR:

- do not truncate the payload
- do not emit a partial QR
- keep non-QR transfer paths available from the same export action

This keeps QR convenient without turning it into the only viable path.

### Decision: Desktop and mobile own different platform adapters over one model

Shared shell core should own the envelope, validation, and secret
classification logic.
Platform packages should keep ownership of:

- desktop file picking, clipboard/text paste, and QR rendering surfaces
- mobile share-sheet/file ingress, QR scanning, and QR rendering surfaces

That keeps platform plugins and OS permissions out of shared shell core.

## Risks / Trade-offs

- Secret-bearing QR or file export can be mishandled by operators.
  Mitigation: make sensitivity explicit, keep export operator-initiated, and
  avoid background generation or silent persistence.
- Preserving managed-provider mode across devices can accidentally duplicate
  provider records.
  Mitigation: import with fresh local ids and restore from explicit snapshot
  instead of trusting source ids.
- QR payload size can become brittle if profile envelopes grow.
  Mitigation: define QR gating and keep file/share/text fallback from the same
  envelope.
- Desktop and mobile could diverge in import semantics.
  Mitigation: put envelope parsing, validation, and source-mode restoration in
  shared shell core and keep platform code thin.

## Migration Plan

1. Add the portable-profile envelope and import/export shaping in shared shell
   core.
2. Add desktop export/import actions around the shared envelope, including QR
   rendering and file/text paths.
3. Add mobile export/import actions around the same envelope, including QR scan
   and share/file paths.
4. Keep import as a profile-workspace action that does not auto-start runtime
   or browser flows.
5. Update docs and tests, then validate the change strictly.

## Open Questions

- Whether the first shipped desktop import surface should include clipboard
  paste, file import, or both on day one.
- Whether the first shipped export UX should expose one explicit
  secret-bearing transfer action with warning, or separate operator-visible
  secret vs non-secret export actions over the same envelope model.
