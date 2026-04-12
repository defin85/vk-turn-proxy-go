## 1. Contract
- [ ] 1.1 Extend the provider descriptor contract with an optional
      `provider_settings_schema`, including the supported schema subset and
      `x-vkturn-*` rendering/persistence hints.
- [ ] 1.2 Extend the control-plane request/profile contract with a
      `provider_settings` object and field-aware validation errors.
- [ ] 1.3 Define redaction and persistence rules for profile-retained,
      ephemeral, and write-only provider settings.

## 2. Host
- [ ] 2.1 Extend provider adapter descriptors and control-plane models to carry
      provider settings schemas and settings values.
- [ ] 2.2 Validate `provider_settings` during profile upsert and resolution
      start, rejecting undeclared or invalid fields with typed field-aware
      failures.
- [ ] 2.3 Persist only profile-retained provider settings and keep write-only or
      ephemeral values out of ordinary profile reads and events.

## 3. Shells
- [ ] 3.1 Render provider-defined settings in desktop and mobile shells from the
      descriptor contract instead of provider-name-specific widgets.
- [ ] 3.2 Keep provider settings separate from runtime defaults in the shell
      editor surface and local state.
- [ ] 3.3 Redact link-like, write-only, and ephemeral provider settings from
      persisted local shell state.

## 4. Verification
- [ ] 4.1 Add control-plane coverage for schema validation, profile persistence,
      and field-aware failures.
- [ ] 4.2 Add desktop/mobile shell coverage for descriptor-driven provider
      settings rendering, persistence filtering, and fail-closed behavior on
      unsupported field shapes.
