# Mobile GUI Shell Instructions

## Read First

- `mobile/gui_shell/README.md`
- `openspec/specs/mobile-gui-client/spec.md`
- `openspec/specs/android-embedded-mobile-host/spec.md`
- `openspec/specs/platform-tunnel-integration/spec.md`

## Guardrails

- Keep the mobile shell fail-closed when the native bridge or packaged host is missing or incompatible.
- Do not imply device-wide VPN or tunnel support unless the typed platform-tunnel contract and specs explicitly support it.
- Keep provider input links and other secret-bearing values out of persisted plaintext state.
- Keep browser continuation semantics aligned with host-reported challenge metadata instead of shell-local guesses.

## Verification

- Run `dart pub get` from the repository root before shell-local checks.
- Run `cd mobile/gui_shell && flutter analyze && flutter test`.
- If packaged-host or bridge semantics change, also run `go test ./internal/androidembeddedhost ./pkg/clientcontrol`.
