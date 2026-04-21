## 1. Contract
- [ ] 1.1 Add a `supported-provider-rollout` capability that defines the gate
      from researched provider family to shipped supported provider.
- [ ] 1.2 Require shipped-provider promotion to depend on a provider-specific
      contract plus the corresponding artifact-family action surface.
- [ ] 1.3 Keep presets, templates, and research artifacts explicitly
      non-authoritative for shipped support status.

## 2. Rollout behavior
- [ ] 2.1 Define fail-closed behavior for partial host or shell readiness so a
      provider family does not enter the ordinary shipped catalog early.
- [ ] 2.2 Define how the repository records "planned" or "pending rollout"
      state without claiming ordinary operator-facing support.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-48-flow-6-provider-expansion-shipping-gates --strict --no-interactive`
