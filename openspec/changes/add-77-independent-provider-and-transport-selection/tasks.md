## 1. Product contract

- [ ] 1.1 Define provider sources/contours and VPN transport profiles as
      independent operator-facing catalogs.
- [ ] 1.2 Define the compatibility matrix that combines provider artifact,
      carrier family, engine family, host adapter, and required profile kind.
- [ ] 1.3 Keep provider records from owning VPN transport secrets or implicit
      transport-profile defaults.
- [ ] 1.4 Keep VPN transport profiles from owning provider credentials,
      signaling state, or provider-source defaults.

## 2. Shell UX

- [ ] 2.1 Add desktop requirements for separate Provider Sources and VPN
      Transport Profiles workspaces plus a route/plan surface that combines
      the selected axes.
- [ ] 2.2 Add mobile requirements for the same separated Provider Sources and
      VPN Transport Profiles destinations.
- [ ] 2.3 Show unsupported, setup-needed, degraded, and missing-evidence states
      for combinations without silently substituting either axis.
- [ ] 2.4 Preserve Home as the primary VPN start/stop owner while provider and
      transport workspaces manage selection and setup.

## 3. Control-plane and runtime behavior

- [ ] 3.1 Extend control-plane contract so startup intent can carry explicit
      provider-source/resolution and transport-profile references.
- [ ] 3.2 Extend runtime execution planning so plan support reports the selected
      source/profile compatibility reason.
- [ ] 3.3 Ensure unsupported combinations fail closed before provider or native
      adapter startup claims readiness.

## 4. Validation

- [ ] 4.1 Run
      `openspec validate add-77-independent-provider-and-transport-selection --strict --no-interactive`.
- [ ] 4.2 Run `openspec validate --all --strict --no-interactive`.
- [ ] 4.3 Run `git diff --check`.
