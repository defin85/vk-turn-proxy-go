## 1. Contract model

- [x] 1.1 Extend the profile-store capability with editable profile-kind
      schemas, supported field metadata, and structured lifecycle actions.
- [x] 1.2 Define the `wireguard_native_v1` structured draft model, including
      display name, private-key handling, interface addresses, DNS, MTU, peer
      public key, allowed IPs, endpoint, and host-supported optional fields.
- [x] 1.3 Define stable field descriptors, secret update intent
      (`preserve_existing`, `replace_submitted`, `generate_host`), field-aware
      validation errors, and redaction rules for structured create/update
      requests.
- [x] 1.4 Define host-side key generation semantics and safe public-key or
      fingerprint response metadata.

## 2. Host and control plane

- [x] 2.1 Add versioned client-control operations for structured create,
      update, validation preview, and host-side key generation.
- [x] 2.2 Normalize `.conf` imports and structured saves into the same
      `wireguard_native_v1` store representation.
- [x] 2.3 Make structured updates atomic: invalid edits must not replace the
      previous startable profile or default binding.
- [x] 2.4 Persist structured profiles in the existing host-owned store with
      private storage permissions and backup exclusion.
- [x] 2.5 Ensure accepted structured fields are materialized into the
      WireGuard execution lease or rejected as unsupported.
- [x] 2.6 Gate Android and desktop host capability advertisement on real
      structured create/update, validation, persistence, redaction, and
      materialization support.

## 3. Shell UX

- [x] 3.1 Add a shared VPN transport profile editor surface in
      `packages/flutter_shell_core`.
- [x] 3.2 Wire the mobile Home/Routing setup-needed flow to offer create/edit
      as a primary product path, with `.conf` import as an alternate path.
- [x] 3.3 Wire the desktop Routing/Home setup-needed flow to the same editor
      when a desktop host advertises structured profile editing.
- [x] 3.4 Keep stored secret fields redacted after save; require explicit
      replacement or host-side regeneration to change them.
- [x] 3.5 Show field-level errors without leaking submitted secret values.

## 4. Verification

- [x] 4.1 Add Go contract tests for capability negotiation, structured
      create/update, atomic invalid updates, redaction, and key generation.
- [x] 4.2 Add Android embedded-host tests proving structured profiles persist
      in the no-backup store and materialize for `android_vpn_service`.
      - [x] Structured profile no-backup persistence is covered by
            `TestManagerPersistsStructuredTransportProfileStoreAcrossRestarts`.
      - [x] Direct end-to-end attach from a structured profile through a
            resolved TURN artifact into `android_vpn_service` is split to
            `add-75-relaydock-native-vpn-management`; add-74 stops at the
            editor/profile-store materialization contract.
- [x] 4.3 Add carrier/materializer tests proving accepted fields affect the
      WireGuard execution lease and unsupported fields fail closed.
- [x] 4.4 Add Flutter controller/widget tests for mobile and desktop create,
      edit, import fallback, replace, forget, and field-error flows.
- [x] 4.5 Run targeted Go and Flutter verification for the touched packages.
- [x] 4.6 Run
      `openspec validate add-74-vpn-transport-profile-editor --strict --no-interactive`.
