# Change: Add provider-defined entry fields

## Why
`add-20-multi-provider-runtime-families` made provider entry descriptor-driven,
but the shipped contract still assumes one provider input value plus generic
runtime defaults.

If a provider needs reusable operator-configured settings such as region,
account mode, or device selector, the remaining options are to hard-code shell
forms per provider or to overload runtime defaults with provider-owned meaning.
Both options break the provider boundary that add-20 introduced.

## What Changes
- Extend provider descriptors with an optional schema-backed
  `provider_settings_schema` for provider-defined, user-configurable entry
  fields.
- Add a `provider_settings` object to saved profiles and resolution-start
  requests so reusable provider settings travel through the same provider-owned
  contract instead of shell-specific branches.
- Define strict validation, redaction, and persistence rules so profile-retained
  non-secret values can be reused while write-only or ephemeral values are
  never treated as ordinary saved profile metadata.
- Update desktop and mobile shells to render supported settings generically from
  descriptor metadata and to fail closed on unsupported field shapes.

## Impact
- Affected specs: `client-control-plane`, `provider-runtime-artifacts`,
  `desktop-gui-client`, `mobile-gui-client`
- Affected code: `internal/provider/...`, `pkg/clientcontrol/...`,
  `desktop/gui_shell/...`, `mobile/gui_shell/...`
