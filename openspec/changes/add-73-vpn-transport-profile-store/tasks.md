## 1. Contract model
- [ ] 1.1 Define the `vpn-transport-profile-store` schema, including profile
      id, kind, version, display metadata, validation state, compatibility
      state, redaction rules, and host-owned secret-material references.
- [ ] 1.2 Define the first concrete kind, `wireguard_native_v1`, and the
      WireGuard `.conf` import adapter without making `.conf` the generic store
      contract.
- [ ] 1.3 Define profile lifecycle actions: list, import/create, validate,
      replace, forget, and select for startup.
- [ ] 1.4 Define diagnostics and event redaction so ordinary reads never expose
      raw private keys, peer secrets, or host-private filesystem paths.
- [ ] 1.5 Define default-selection semantics as profile-id-backed bindings
      scoped to a host adapter and execution plan, not as an implicit global
      fallback.

## 2. Control-plane and planning
- [ ] 2.1 Add profile-store capability negotiation to the versioned
      client-control plane.
- [ ] 2.2 Extend runtime execution plans with required transport profile kinds,
      supported material sources, and missing/invalid/incompatible status.
- [ ] 2.3 Add typed platform-tunnel prerequisite/stage values for transport
      profile validation so missing material is not reported as generic host
      implementation failure.
- [ ] 2.4 Extend platform-tunnel startup requests to carry a profile reference
      or default-profile selection, not a raw config or path.
- [ ] 2.5 Fail closed when the selected plan requires transport material and no
      compatible configured profile exists.

## 3. Host and storage
- [ ] 3.1 Migrate the Android explicit WireGuard import into a
      `wireguard_native_v1` profile record owned by the embedded host.
- [ ] 3.2 Replace shell-visible Android WireGuard path handling with host-owned
      profile-id/status/materialization calls.
- [ ] 3.3 Keep storage backend details platform-private and covered by tests for
      permissions, backup exclusion, redaction, replacement, and forget
      behavior.
- [ ] 3.4 Ensure future desktop host materializers can consume the same profile
      reference contract without Android API names.
- [ ] 3.5 Reclassify desktop WireGuard env/default file paths as development
      migration inputs only; product desktop startup must consume transport
      profile references before advertising profile-store support.

## 4. Shell UX
- [ ] 4.1 Rename the mobile setup surface from hidden/specific WireGuard config
      recovery to VPN transport profile setup, with WireGuard shown as the
      first supported profile type.
- [ ] 4.2 Show profile status as not configured, configured, invalid, or
      incompatible with the selected execution plan.
- [ ] 4.3 Provide import/replace/forget actions through generic profile-store
      commands, while retaining a WireGuard `.conf` picker only as the first
      import adapter.
- [ ] 4.4 Keep VPN startup disabled or setup-gated when a required profile is
      missing or incompatible.

## 5. Verification
- [ ] 5.1 Add control-plane tests proving ordinary profile reads are redacted
      and startup requests use profile refs, including stale/default profile
      failure cases.
- [ ] 5.2 Add Android embedded-host tests for import, replace, forget,
      materialization, and fail-closed missing profile behavior.
- [ ] 5.3 Add mobile widget/controller tests for generic transport-profile
      setup, compatible WireGuard profile status, and incompatible/missing
      profile startup blocking.
- [ ] 5.4 Add regression checks proving packaged Android builds still reject
      hidden `phone1.conf` or equivalent seed assets.
- [ ] 5.5 Add desktop contract tests proving env/default WireGuard paths do not
      satisfy product profile-store support claims.
- [ ] 5.6 Run
      `openspec validate add-73-vpn-transport-profile-store --strict --no-interactive`.
