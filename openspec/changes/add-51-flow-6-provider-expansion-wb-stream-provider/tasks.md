## 1. Contract
- [ ] 1.1 Add a `wb-stream-provider` capability for the provider descriptor,
      typed entry contract, redacted ordinary reads, and fail-closed behavior.
- [ ] 1.2 Bind successful WB resolution to the `conference_room` artifact
      family and the committed conference-room action surface.
- [ ] 1.3 Keep local conference execution, `generic-turn` export, and
      unapproved browser-surface claims out of scope.

## 2. Evidence and rollout
- [ ] 2.1 Require descriptor and shell rollout to stay behind the flow-6
      shipping gate until WB-specific evidence exists.
- [ ] 2.2 Define fail-closed handling for blocked, incomplete, or unsupported
      WB provider flows.

## 3. Validation
- [ ] 3.1 Run
      `openspec validate add-51-flow-6-provider-expansion-wb-stream-provider --strict --no-interactive`
