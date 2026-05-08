## 1. Contract and security boundary

- [x] 1.1 Document the live product gap between saved-profile transfer and
      VPN transport-profile transfer.
- [x] 1.2 Define the encrypted portable transport-profile envelope and
      passphrase-based transfer semantics.
- [x] 1.3 Define preview-first import, fresh local ids, and no implicit default
      binding or auto-start on destination hosts.
- [x] 1.4 Keep saved-profile transfer, runtime handoff export, ordinary backup,
      and VPN transport-profile transfer as distinct workflows.

## 2. Store and control-plane planning

- [x] 2.1 Extend `vpn-transport-profile-store` with explicit encrypted export
      and import requirements for secret-bearing transport profiles.
- [x] 2.2 Extend `client-control-plane` with typed transport-profile export,
      preview/import, and confirmation actions.
- [x] 2.3 Define one dedicated `portable_transfer` capability block plus the
      per-profile `export_portable` action, including stable `text_payload`,
      `file_payload`, and `qr_payload` path identifiers.
- [x] 2.4 Define fail-closed behavior for wrong passphrase, incompatible host,
      unsupported envelope version, and missing required profile kind.
- [x] 2.5 Lock the crypto profile (`Argon2id` + `XChaCha20-Poly1305`), the
      minimum reviewed KDF floor, and which safe metadata may appear outside
      ciphertext while keeping passphrase/decrypted-payload material out of
      ordinary events, diagnostics, and logs.
- [x] 2.6 Define exact-duplicate import preview semantics, including safe
      duplicate fingerprints, redacted references to existing local profiles,
      and no second record for exact duplicates in the first shipped slice.
- [x] 2.7 Define the first shipped preview-outcome taxonomy
      (`blocked`/`already_present`/`importable`) plus non-blocking
      `display_name_conflict` warnings and host-suggested resolved local names.

## 3. Shell UX planning

- [x] 3.1 Extend the mobile VPN transport-profile manager and setup surfaces
      with explicit export/import actions and sensitivity warnings.
- [x] 3.2 Extend the desktop VPN transport-profile manager and setup surfaces
      with the same explicit export/import semantics.
- [x] 3.3 Make QR part of the first shipped path: desktop/mobile QR render,
      mobile QR scan/import, single-payload-only QR semantics, and fail-closed
      QR size handling alongside file/text/share behavior.
- [x] 3.4 Keep saved-profile export copy and VPN transport-profile export copy
      clearly separated in shell UX.
- [x] 3.5 Show an explicit `already on this device` preview state for exact
      duplicates and route the operator toward the existing local profile
      instead of offering duplicate import confirmation.
- [x] 3.6 Show `display_name_conflict` as a non-blocking import preview warning
      with the host-suggested local display name, without requiring an inline
      rename editor in the first shipped slice.

## 4. Evidence gate

- [x] 4.1 Require implementation-time verification that a transferred saved
      profile still blocks startup when the destination host lacks the matching
      VPN transport profile.
- [x] 4.2 Require implementation-time verification that importing the
      transport profile keeps startup fail-closed until explicit operator
      confirmation completes and a later transport-profile selection binds the
      execution plan.
- [x] 4.3 Validate
      `add-82-vpn-transport-profile-portable-transfer` with
      `openspec validate add-82-vpn-transport-profile-portable-transfer --strict --no-interactive`.
