## 1. Shared portable profile contract
- [ ] 1.1 Add a versioned portable-profile envelope in shared shell core,
      separate from ordinary persisted shell-state files and from
      `export_handoff`.
- [ ] 1.2 Define shared import shaping for managed-provider-backed profiles,
      including new local ids and restoration of managed/custom source mode
      without silently overwriting local records.
- [ ] 1.3 Add shared tests for envelope round-trip behavior, secret
      classification, invalid payload rejection, and QR-size gating.

## 2. Desktop shell profile transfer
- [ ] 2.1 Add explicit desktop profile export from the profile workspace with
      file/text transfer and QR rendering from the shared envelope.
- [ ] 2.2 Add desktop profile import from supported file or pasted-envelope
      flows into the Profiles workspace with preview/confirmation.
- [ ] 2.3 Keep desktop import/export fail-closed for invalid payloads,
      oversized QR payloads, and secret-bearing transfers that need explicit
      operator review.

## 3. Mobile shell profile transfer
- [ ] 3.1 Add explicit mobile profile export with platform-native share/file
      actions and QR rendering from the shared envelope.
- [ ] 3.2 Add mobile profile import from supported file/share ingress and QR
      scan into the Profiles workflow.
- [ ] 3.3 Keep mobile import/export fail-closed for invalid QR/file payloads,
      oversized QR payloads, and secret-bearing transfers that need explicit
      operator review.

## 4. Validation
- [ ] 4.1 Update shared, desktop, and mobile tests for portable profile
      transfer, managed-provider restoration, and no-auto-start behavior.
- [ ] 4.2 Update desktop/mobile shell docs to describe portable profile
      transfer and its security boundaries.
- [ ] 4.3 Run `openspec validate add-31-portable-profile-transfer --strict
      --no-interactive`.
