## 1. Information Architecture
- [ ] 1.1 Redesign the mobile `Providers` root so saved managed provider records
  are the primary list content.
- [ ] 1.2 Keep provider detail or editing as drill-down content on phone and as
  optional companion detail on wider layouts, with compact back navigation
  returning to the list-first root.

## 2. Create Flow
- [ ] 2.1 Add an explicit `New provider` flow that separates `Start from
  template` from `Blank provider`.
- [ ] 2.2 Move template browsing out of the root page into a dedicated picker or
  sheet that can scale to many templates.
- [ ] 2.3 Support search or family-based filtering in the template picker when
  the catalog grows.

## 3. Copy and Taxonomy
- [ ] 3.1 Replace operator-facing `App-owned provider catalog` copy with
  `Provider family`, `Supported provider families`, and `Templates` where
  appropriate.
- [ ] 3.2 Keep the internal shell-owned catalog model intact and explicit in
  code/spec comments, without surfacing that term as the primary UI label.

## 4. Validation
- [ ] 4.1 Run `openspec validate add-34-mobile-provider-workspace-list-first --strict --no-interactive`.
- [ ] 4.2 Add or update widget coverage for list-first `Providers`, template
  entry points, compact drill-down/back behavior, wide list-detail behavior,
  and the absence of the old overloaded root layout.
- [ ] 4.3 Validate the redesigned `Providers` flow manually on a mobile device
  or emulator after implementation, covering both compact and wide layouts.
