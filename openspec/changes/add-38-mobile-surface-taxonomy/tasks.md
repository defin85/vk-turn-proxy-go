## 1. Taxonomy
- [x] 1.1 Define and document the mobile interaction surface taxonomy for
  local pickers, catalog/library flows, and compact preview/confirmation/status
  surfaces.
- [x] 1.2 Audit the existing mobile shell surfaces against that taxonomy and
  map each current dialog, sheet, and route to its target pattern.

## 2. Provider Create Flow
- [x] 2.1 Replace the centered `New provider` chooser dialog with a dedicated
  follow-on mobile surface that can scale to provider families, templates,
  search, and multiple actions.
- [x] 2.2 Preserve normal mobile back navigation so dismissing the provider
  create flow returns the operator to the `Providers` root without losing
  current context.

## 3. Local and Compact Surfaces
- [x] 3.1 Keep `Routing profile` and `App scope` as bottom-sheet local pickers
  and align any equivalent local choice surfaces to the same pattern.
- [x] 3.2 Keep compact preview, confirmation, and short status-summary surfaces
  on dialog-sized overlays instead of turning them into catalog-style flows.

## 4. Validation
- [x] 4.1 Run `openspec validate add-38-mobile-surface-taxonomy --strict --no-interactive`.
- [x] 4.2 Add or update widget coverage for the provider create surface,
  routing pickers, and the chosen compact dialog-sized surfaces.
- [x] 4.3 Validate the resulting mobile interaction patterns manually on a
  physical device or emulator.
