## 1. Contract model

- [ ] 1.1 Extend the profile-store capability with editable profile-kind
      schemas, supported field metadata, and structured lifecycle actions.
- [ ] 1.2 Define the `wireguard_native_v1` structured draft model, including
      display name, private-key handling, interface addresses, DNS, MTU, peer
      public key, allowed IPs, endpoint, and host-supported optional fields.
- [ ] 1.3 Define field-aware validation errors and redaction rules for
      structured create/update requests.
- [ ] 1.4 Define host-side key generation semantics and safe public-key or
      fingerprint response metadata.

## 2. Host and control plane

- [ ] 2.1 Add versioned client-control operations for structured create,
      update, validation preview, and host-side key generation.
- [ ] 2.2 Normalize `.conf` imports and structured saves into the same
      `wireguard_native_v1` store representation.
- [ ] 2.3 Make structured updates atomic: invalid edits must not replace the
      previous startable profile or default binding.
- [ ] 2.4 Persist structured profiles in the existing host-owned store with
      private storage permissions and backup exclusion.
- [ ] 2.5 Ensure accepted structured fields are materialized into the
      WireGuard execution lease or rejected as unsupported.

## 3. Shell UX

- [ ] 3.1 Add a shared VPN transport profile editor surface in
      `packages/flutter_shell_core`.
- [ ] 3.2 Wire the mobile Home/Routing setup-needed flow to offer create/edit
      as a primary product path, with `.conf` import as an alternate path.
- [ ] 3.3 Wire the desktop Routing/Home setup-needed flow to the same editor
      when a desktop host advertises structured profile editing.
- [ ] 3.4 Keep stored secret fields redacted after save; require explicit
      replacement or host-side regeneration to change them.
- [ ] 3.5 Show field-level errors without leaking submitted secret values.

## 4. Verification

- [ ] 4.1 Add Go contract tests for capability negotiation, structured
      create/update, atomic invalid updates, redaction, and key generation.
- [ ] 4.2 Add Android embedded-host tests proving structured profiles persist
      in the no-backup store and materialize for `android_vpn_service`.
- [ ] 4.3 Add carrier/materializer tests proving accepted fields affect the
      WireGuard execution lease and unsupported fields fail closed.
- [ ] 4.4 Add Flutter controller/widget tests for mobile and desktop create,
      edit, import fallback, replace, forget, and field-error flows.
- [ ] 4.5 Run targeted Go and Flutter verification for the touched packages.
- [ ] 4.6 Run
      `openspec validate add-74-vpn-transport-profile-editor --strict --no-interactive`.
