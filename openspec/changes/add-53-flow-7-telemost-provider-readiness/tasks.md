## 1. Admission boundary
- [ ] 1.1 Add a `telemost-provider-readiness` capability that keeps legacy
      Telemost mentions separate from reviewed operator-facing support.
- [ ] 1.2 Define the minimum support gate for Telemost promotion: committed
      provider contract plus repo-owned release verification for the exact
      claimed surface.
- [ ] 1.3 Keep `generic_turn` semantics out of Telemost support claims unless
      a separate transport-ready artifact exists.

## 2. Auth and research posture
- [ ] 2.1 Define the split between room-creation prerequisites and
      join/runtime-attach prerequisites.
- [ ] 2.2 Keep community PoCs, public room URLs, and operator bootstrap assets
      explicitly non-authoritative for shipped support status.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-53-flow-7-telemost-provider-readiness --strict --no-interactive`
