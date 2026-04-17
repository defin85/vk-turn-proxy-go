## Context

The repository already runs desktop, mobile, and `flutter_shell_core` through
one Flutter workspace. That workspace now contains shared widgets plus shared
display-oriented model helpers, while the mobile and desktop shells still own
their `MaterialApp` roots independently.

This creates two distinct localization surfaces:

- shell-owned operator copy such as navigation labels, actions, empty states,
  status labels, and shared widget chrome
- host-supplied display metadata such as provider names, descriptions, setting
  labels, and field-aware validation or availability messages

Treating those as one source would either force the shell to translate host
data locally from unstable English strings or force the control plane to own
ordinary shell chrome. Both outcomes are wrong.

## Goals

- Give desktop, mobile, and `flutter_shell_core` one shared typed translation
  boundary.
- Keep locale persistence and platform adapters app-local.
- Keep machine-readable ids, keys, and violation codes locale-neutral.
- Let shells render localized provider metadata when the host can provide it,
  while remaining compatible with older or untranslated hosts.
- Support ordinary `flutter analyze` and `flutter test` workflows inside the
  workspace.

## Non-Goals

- Localizing runtime logs, CLI output, or Go server internals.
- Translating user-authored names such as saved profile names or saved provider
  names.
- Making locale a host-global setting that changes every connected shell.
- Requiring every host to localize every descriptor before updated shells can
  function.

## Decisions

### Decision: Add a dedicated shared Flutter i18n package

Add `packages/flutter_shell_i18n` as the shared package for shell-owned
translations used by desktop, mobile, and `flutter_shell_core`.

Why:

- `flutter_shell_core` already contains reusable UI and display labels, so
  app-local translation files would force callback plumbing back down into
  shared widgets.
- A dedicated package keeps translation ownership aligned with the existing
  workspace split: platform-neutral copy in shared packages, plugin-backed
  locale persistence in app-local code.

### Decision: Use `slang` with ARB inputs instead of app-local `gen_l10n`

Use `slang` and `slang_flutter` as the workspace i18n engine, with ARB source
files and generated source inside repository-owned package paths.

Why:

- Official Flutter `gen_l10n` is a good baseline for single applications, but
  this repository is a workspace with multiple app packages plus a shared UI
  package.
- Flutter now requires generated localization source in `lib/`, and workspace
  setups have known tool friction around `generate: true`.
- `slang` supports multi-package usage, explicit shared generation, and still
  accepts ARB as the source format so the repository stays compatible with
  Flutter translation tooling and translator expectations.

Alternative considered:

- Per-app `gen_l10n` in `desktop/gui_shell` and `mobile/gui_shell`.
  Rejected because it leaves shared package copy without a clean ownership
  model and increases drift between shells.

### Decision: Keep locale preference shell-local, not host-global

Each shell app keeps its own persisted locale override and falls back to the
device locale when no override exists. Locale persistence remains app-local
because desktop and mobile already own platform adapters and persistence
plugins.

Why:

- Locale is an operator presentation preference, not runtime transport state.
- A host-global locale would couple multiple shells to one mutable display
  setting and complicate compatibility.

### Decision: Separate shell-owned copy from host-supplied metadata

Shell-owned copy is always translated from the shared i18n package. Host or
control-plane metadata may supply localized display fields, but the shell never
attempts to infer translations by parsing English base strings.

Why:

- Host descriptors already carry display text that can differ by provider and
  by runtime support.
- Translating those strings by guesswork would be lossy and unstable.

### Decision: Extend control-plane display metadata with localized variants and fallback

Provider descriptor names and descriptions, provider setting titles and
descriptions, and validation or availability messages gain optional localized
variants keyed by locale, while existing base fields remain the fallback.

The shell expresses locale preference through the local HTTP control-plane
surface, for example via `Accept-Language`, but machine-readable ids remain the
source of truth for program logic.

Why:

- The shell needs localized display metadata for provider forms and status
  surfaces.
- Older hosts and partially translated hosts must remain compatible.

## Consequences

### Positive

- One shared translation API across both shells and shared widgets.
- No need to keep English display labels embedded in model enums or widget
  helpers.
- Backward compatibility for existing hosts because base strings remain valid
  fallback data.

### Negative

- Introduces a new shared package and a generation workflow.
- Requires a control-plane schema extension for localized metadata.
- Requires touching both shell apps plus the shared package in one rollout.

## Migration Plan

1. Add the shared i18n package and wire workspace resolution.
2. Move shell-owned copy out of hardcoded UI strings and shared model label
   getters.
3. Add locale bootstrap and persistence in desktop and mobile app roots.
4. Extend control-plane descriptor and validation display metadata with
   localized variants plus fallback behavior.
5. Update shared widgets and shell screens to use the new i18n boundary.
6. Add locale-aware widget tests and compatibility coverage for untranslated
   hosts.

## Risks and Mitigations

- Risk: half-translated UI if host metadata remains English.
  Mitigation: require explicit fallback semantics and keep shell-owned copy
  separate from host-supplied metadata.
- Risk: workspace codegen churn.
  Mitigation: keep generated source in repo-owned package paths and document a
  single repo-owned generation step.
- Risk: logic accidentally depending on localized text.
  Mitigation: keep ids, field keys, and violation codes stable and
  locale-neutral in the control-plane contract.

## Open Questions

- Whether the first locale slice should ship with only `en` and `ru` or also
  reserve additional locales in the shared package scaffold.
- Whether locale switching belongs in a dedicated settings surface immediately
  or can first ship through a compact shell menu entry.
