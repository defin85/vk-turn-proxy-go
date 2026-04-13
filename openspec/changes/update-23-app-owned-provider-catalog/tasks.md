## 1. Shared model and migration
- [x] 1.1 Add a shared app-owned supported-provider catalog in `flutter_shell_core` and remove speculative preset entries that do not map to shipped supported providers.
- [x] 1.2 Add shared managed-provider record models, draft helpers, shell-local source metadata, and persisted-state migration from the current provider-config shape where migration is safe.
- [x] 1.3 Add shared preset definitions that seed managed-provider drafts only for supported provider families.

## 2. Control-plane and contract alignment
- [x] 2.1 Update shell/control-plane contract usage so desktop and mobile no longer require `Capability.providerConfigs` or host-managed provider-config CRUD for their primary reusable-provider workflow.
- [x] 2.2 Keep provider materialization snapshot-based at the control-plane boundary and add coverage that managed-provider selection compiles down to ordinary profile/start payloads.
- [x] 2.3 Update host and shell compatibility handling so host descriptors act as runtime availability and validation overlays, not the sole operator-facing provider catalog, and host-side provider-config endpoints remain optional compatibility surfaces only.

## 3. Desktop and mobile workflow updates
- [x] 3.1 Replace the `Provider configs` workflow surface with a managed `Providers` surface on desktop and mobile.
- [x] 3.2 Update preset flows so they create or seed managed-provider records instead of acting as standalone provider families.
- [x] 3.3 Update profile editors so they can start from either a managed provider record or a custom provider path without mutating the managed-provider catalog, keep prompt-only/session-scoped inputs outside managed provider persistence, and restore managed-provider mode when reopening a saved profile that came from a managed provider.

## 4. Verification
- [x] 4.1 Add controller/model tests for migration, managed-provider apply, zero-field managed providers, preset seeding, custom-provider fallback, restore-to-managed-mode behavior, and host negotiation without `provider_configs`.
- [x] 4.2 Add desktop/mobile widget coverage for the new provider workspace and profile mode selection.
- [x] 4.3 Run `flutter test` for desktop/mobile shells, relevant Go tests, and `openspec validate update-23-app-owned-provider-catalog --strict --no-interactive`.
