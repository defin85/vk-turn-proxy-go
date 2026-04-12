## 1. Contract
- [x] 1.1 Add a typed `provider-runtime-artifacts` capability that defines
      provider descriptors, artifact families, capability-gated actions,
      auth/browser policy, and redaction rules across more than one runtime
      family
- [x] 1.2 Extend the local host contract so shells can discover provider
      descriptors and resolution capabilities without hard-coded provider UX,
      and negotiate the new multi-provider surface through an explicit host
      capability
- [x] 1.3 Add the typed provider input envelope for descriptor-driven
      resolution start and remove the legacy untyped start request once
      first-party shells migrate to the add-20 contract

## 2. Host
- [x] 2.1 Add host APIs and models for provider catalog discovery, typed
      artifact-family resolution records, provider auth/browser constraints,
      and explicit capability-gated actions with stable machine-readable
      identifiers
- [x] 2.2 Keep same-device execution family-specific so unsupported families
      fail closed instead of creating fake sessions or guessed exports
- [x] 2.3 Preserve the current secret-redaction boundary for non-TURN tokens in
      ordinary reads, events, diagnostics, and persisted shell state
- [x] 2.4 Report action execution ownership so shells know whether an action is
      host-executed, shell-local, or shell-external
- [x] 2.5 Remove the legacy `provider-resolution-handoff` path once
      first-party shells and verification no longer depend on it

## 3. Shells
- [x] 3.1 Update the desktop shell to build provider entry flows from host
      descriptors rather than provider-name-specific assumptions, including
      auth posture and browser policy
- [x] 3.2 Update desktop post-resolution UX so actions come from artifact
      capabilities and unsupported families stay explicit and fail-closed
- [x] 3.3 Update the mobile shell to consume the same descriptor and
      artifact-capability contract with platform-native presentation and
      explicit handling for providers that require an external browser
- [x] 3.4 Migrate persisted desktop/mobile draft state through descriptors,
      keep only non-secret operator-managed state, and remove VK-specific or
      TURN-only fallback branches from add-20 surfaces

## 4. Verification
- [x] 4.1 Add host/control-plane coverage for provider catalog discovery,
      artifact-family resolution state, auth/browser descriptor fields,
      negotiation of the new host capability, typed input envelopes, redaction,
      and capability-gated action failures
- [x] 4.2 Add desktop/mobile shell coverage for descriptor-driven provider UX
      and capability-driven post-resolution actions, including external-browser
      requirements, state migration, and no-silent-fallback behavior on the
      shipped add-20 surface
- [x] 4.3 Run `openspec validate add-20-multi-provider-runtime-families
      --strict --no-interactive` plus the smallest relevant repo verification
      set once implementation begins
