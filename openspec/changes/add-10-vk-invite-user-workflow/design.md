## Context
Live VK verification now shows the end-to-end path that users actually have to follow:
- a normal VK call is created outside the product
- an invite link is shared out-of-band
- the product starts from that invite link
- the user may need to continue in a controlled browser and click `Join`
- the session becomes transport-ready only after that browser boundary is crossed and the runtime finishes startup

The repository already specifies provider debug contours, runtime transport behavior, and GUI/control-plane building blocks, but it does not yet state the canonical user workflow that ties those pieces together.

## Goals
- Define one supported VK workflow that product docs, GUI surfaces, and support playbooks can share.
- Keep the end-user input minimal and centered on the invite link.
- Keep peer, TURN mode, DTLS mode, and similar transport details operator-managed in the standard flow.
- Make the browser continuation and post-preview `Join` step explicit in the contract.
- Preserve stage-aware failures and diagnostics when the live flow does not reach readiness.

## Non-Goals
- Create, rotate, revoke, or administer VK calls from inside the product.
- Replace VK's own conferencing UI or embed provider-specific browser logic inside the GUI shell.
- Remove advanced transport controls needed for development, support, or compatibility work.
- Claim that every VK invite is always immediately transport-ready without user browser action.

## Decisions
- Treat a standard `https://vk.com/call/join/...` link as the supported VK session input for end users.
- Make the recommended actor model explicit: an organizer or dispatcher creates the VK call and shares the invite link, while the end user consumes that invite inside the product.
- Allow self-created invites to use the same runtime path, but keep organizer-created invites as the canonical documented workflow.
- Separate invite intake from operator-managed runtime defaults so normal users are not asked to edit peer endpoints or transport policy.
- Keep the browser continuation explicit and host-driven; the product may instruct the user to continue in the browser, but it does not claim `ready` until the user progresses beyond preview and transport startup succeeds.

## Alternatives Considered
- Let the product create VK calls directly.
  Rejected because that would expand provider scope from invite consumption into call lifecycle ownership.
- Expose raw peer and transport fields as standard VK session inputs.
  Rejected because that makes the common workflow support-heavy and blurs operator-only concerns into the end-user path.
- Treat browser preview as effectively joined.
  Rejected because live evidence shows preview-only state can still fail closed before transport-ready credentials appear.

## Risks / Trade-offs
- VK invite lifetime and browser/login state remain provider-controlled and can still block startup.
  Mitigation: keep the workflow explicit, surface stage-aware failures, and require a fresh invite or browser retry instead of inventing silent fallback behavior.
- Hiding transport knobs from the standard path makes ad-hoc debugging less immediate for advanced operators.
  Mitigation: preserve advanced/manual surfaces, but keep them separate from the normal user workflow.
- Different deployments may disagree about who the "organizer" is.
  Mitigation: specify the role boundary functionally: whoever can create and distribute the invite is outside the runtime product surface.

## Migration Plan
1. Add the user-workflow capability and document it in the repo/operator docs.
2. Update GUI and control-plane surfaces so the standard VK path is invite-first and operator-managed.
3. Add or refresh compatibility and integration coverage for preview-only, post-join ready, and stage-aware failure outcomes.

## Open Questions
- Whether the desktop app should later register an OS-level deep-link handler for `vk.com/call/join/...` links instead of relying only on paste/manual entry.
- Whether the standard GUI should use explicit "Organizer" / "User" wording or more neutral operational wording such as "shared invite" and "session owner".
