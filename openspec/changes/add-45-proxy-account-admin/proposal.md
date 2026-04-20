# Change: [45] Add proxy account admin

## Why
If the hosted VPS runtime grows beyond one operator-managed server process,
manual SSH edits and repo-local scripts stop being a credible way to create,
update, or revoke end-user proxy access.

The project already has a planned authenticated VPS-local admin boundary in
`add-41-vps-server-admin-web`, but that runtime-admin slice is intentionally
about service health and lifecycle control. Account creation, quota or expiry
policy, and delivery artifacts such as connection links or QR codes are a
different control-plane concern and need their own explicit contract.

## Sequence
- Order: `45`
- Depends on:
  - `add-41-vps-server-admin-web`
- Unblocks:
  - operator-managed proxy account provisioning on the VPS
  - explicit revoke, disable, quota, and expiry workflows without raw config
    edits
  - future account delivery flows such as share links, QR codes, or managed
    config exports

## What Changes
- Add a first-party authenticated proxy account admin capability for the
  project VPS, separate from the runtime-status and service-lifecycle scope of
  `add-41-vps-server-admin-web`.
- Scope the first slice to an allow-listed set of managed proxy
  profiles/inbounds, client or account records, enabled-state, quota or expiry
  policy, delivery artifacts, and audited account lifecycle actions.
- Use 3X-UI as a domain and information-architecture reference for
  `profile/inbound -> client/account -> link or QR -> limits`, but not as a
  security or production-architecture reference.
- Keep generic host administration, arbitrary config editing, billing, tenant
  self-service, and multi-host orchestration out of scope.

## Impact
- Affected specs:
  - `proxy-account-admin`
- Affected code:
  - future VPS-local admin backend account APIs
  - future browser UI for proxy profiles, accounts, and delivery artifacts
  - account-state persistence, audit, and operator runbook docs
