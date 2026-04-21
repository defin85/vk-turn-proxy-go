## 1. Account admin contract
- [ ] 1.1 Define the authenticated VPS-local boundary for managed proxy
      profiles/inbounds and client/account records.
- [ ] 1.2 Define the supported account read model, including enabled-state,
      expiry or quota policy, last-change context, and sanitized delivery
      artifacts.
- [ ] 1.3 Define the supported account lifecycle actions such as create,
      update, disable, revoke, and regenerate delivery material without
      exposing arbitrary shell or raw config editing from the browser.

## 2. Control, secrets, and audit
- [ ] 2.1 Define ownership between browser UI, VPS-local admin backend,
      persistent account state, and the managed proxy runtime so mutations stay
      explicit and fail closed.
- [ ] 2.2 Define the redaction and regeneration boundary for operator-visible
      connection material such as share links, QR codes, or config exports.
- [ ] 2.3 Define audit semantics and failure behavior for invalid policy,
      rejected writes, stale runtime state, and secret-regeneration actions.

## 3. Verification
- [ ] 3.1 Add API and UI acceptance coverage for authenticated list, create,
      update, disable, revoke, and delivery-material flows.
- [ ] 3.2 Add operator docs for the supported account-management workflow,
      redaction rules, recovery, and rollback expectations.
- [ ] 3.3 Run `openspec validate add-45-flow-2-vps-admin-proxy-account-admin --strict --no-interactive`.
