## 1. Server admin contract
- [ ] 1.1 Define the authenticated VPS-local web admin boundary and the
      allow-listed managed-service model for repo-owned server runtimes.
- [ ] 1.2 Define the supported read model for one managed service, including
      build identity, lifecycle state, listen/health context, recent failures,
      and sanitized log or metrics summaries.
- [ ] 1.3 Define the supported lifecycle actions and audit semantics without
      exposing arbitrary shell execution from the browser surface.

## 2. Delivery and control boundary
- [ ] 2.1 Define how the web admin is deployed on the VPS alongside the managed
      server-side runtime.
- [ ] 2.2 Define ownership between browser UI, VPS-local admin backend, and the
      managed services so control remains explicit and fail-closed.
- [ ] 2.3 Define failure behavior for unavailable services, permission
      problems, stale build/config state, and rejected lifecycle actions.

## 3. Verification
- [ ] 3.1 Add API and UI acceptance coverage for authenticated status, logs,
      health context, and lifecycle-action flows.
- [ ] 3.2 Add operator docs for the supported VPS deployment, login, recovery,
      and rollback workflow.
- [ ] 3.3 Run `openspec validate add-41-vps-server-admin-web --strict --no-interactive`.
