## 1. Contract
- [ ] 1.1 Add the `vk-invite-user-workflow` capability and align repo docs with the supported actor model, invite-sharing boundary, and post-preview `Join` requirement

## 2. Product Surfaces
- [ ] 2.1 Add a managed VK invite profile/workflow shape that separates operator-managed runtime defaults from the user-supplied invite link
- [ ] 2.2 Update the desktop GUI and local host flow so the supported path is "paste invite -> continue in browser -> click Join -> ready"
- [ ] 2.3 Keep advanced peer and transport controls outside the standard end-user VK workflow and document them as operator/support tooling

## 3. Verification
- [ ] 3.1 Add or update control-plane and GUI coverage for the managed VK invite workflow
- [ ] 3.2 Add or update compatibility/runtime coverage for preview-only, post-join ready, and stage-aware failure outcomes
- [ ] 3.3 Run the smallest relevant verification set, then `go test ./...`, and `go build ./...`
