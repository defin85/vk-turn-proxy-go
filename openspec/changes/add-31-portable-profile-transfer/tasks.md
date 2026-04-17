## 1. Shared portable profile contract
- [x] 1.1 Add a versioned portable-profile envelope in shared shell core,
      separate from ordinary persisted shell-state files and from
      `export_handoff`.
- [x] 1.2 Define shared import shaping for managed-provider-backed profiles,
      including new local ids, restoration of managed/custom source mode, and
      append-only import semantics without silently overwriting local records
      or treating user templates as imported profile dependencies.
- [x] 1.3 Add shared tests for envelope round-trip behavior, secret
      classification, invalid or unsupported-version payload rejection, and
      QR-size gating.

## 2. Desktop shell profile transfer
- [x] 2.1 Add explicit desktop profile export from the profile workspace with
      file/text transfer and QR rendering from the shared envelope.
- [x] 2.2 Add desktop profile import from supported file or pasted-envelope
      flows into the Profiles workspace with preview/confirmation before local
      records are created.
- [x] 2.3 Keep desktop import/export fail-closed for invalid payloads,
      oversized QR payloads, and secret-bearing transfers that need explicit
      operator review.

## 3. Mobile shell profile transfer
- [x] 3.1 Add explicit mobile profile export with platform-native share/file
      actions and QR rendering from the shared envelope behind app-local
      Android/iOS adapter surfaces.
- [x] 3.2 Add mobile profile import from supported file/share ingress and QR
      scan into the Profiles workflow with preview/confirmation before local
      records are created, without requiring Android-only transfer semantics in
      shared shell core.
- [x] 3.3 Keep mobile import/export fail-closed for invalid QR/file payloads,
      oversized QR payloads, and secret-bearing transfers that need explicit
      operator review.

## 4. Validation
- [x] 4.1 Update shared, desktop, and mobile tests for portable profile
      transfer, managed-provider restoration, and no-auto-start behavior.
- [x] 4.2 Update desktop/mobile shell docs to describe portable profile
      transfer and its security boundaries.
- [x] 4.3 Run `openspec validate add-31-portable-profile-transfer --strict
      --no-interactive`.
