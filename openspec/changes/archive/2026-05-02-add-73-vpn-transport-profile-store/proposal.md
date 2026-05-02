# Change: Add VPN Transport Profile Store

## Why

The current Android recovery work made WireGuard material explicit, but the
result is still too WireGuard-shaped: the UI talks about a WireGuard profile,
the native bridge moves a file path, and startup depends on an imported `.conf`
as if that file were the product contract. That is a useful fail-closed patch,
but it risks locking future VPN transports to WireGuard-specific storage,
validation, diagnostics, and UX.

The product needs a transport-profile layer that can hold WireGuard today and
later support other engine families without redesigning the mobile shell,
client-control plane, Android bridge, or platform-tunnel startup contract each
time.

## What Changes

- Add a new `vpn-transport-profile-store` capability for app-owned VPN
  transport profiles.
- Define a transport profile as typed, versioned, redacted runtime material
  metadata plus host-owned secret material, not as a shell-visible path or raw
  config blob.
- Treat WireGuard `.conf` as one import adapter for `wireguard_native_v1`, not
  as the generic runtime contract. Any future export path must be an explicit
  secret-bearing action, not an ordinary profile read.
- Extend runtime execution planning so plans declare required transport profile
  kinds and fail closed when no compatible configured profile exists.
- Extend the client-control plane so shells manage profiles through stable
  profile ids/status/actions and pass references into startup, rather than raw
  material or filesystem paths.
- Extend Android/mobile contracts so the UI presents a generic VPN transport
  profile workflow while the first implemented engine remains WireGuard.

## Impact

- Affected specs: `vpn-transport-profile-store` (new),
  `runtime-execution-planning`, `client-control-plane`,
  `platform-tunnel-integration`, `android-embedded-mobile-host`,
  `desktop-sidecar-host`, `mobile-gui-client`, `desktop-gui-client`,
  `wireguard-turn-carrier`
- Affected code: future `pkg/clientcontrol` schema/capabilities,
  `internal/androidembeddedhost`, platform-tunnel hosts, mobile/desktop shell
  settings UI, transport materializers, diagnostics redaction, import/export
  adapters, tests
- Migration impact: the existing explicit Android WireGuard import can become
  the first `wireguard_native_v1` profile record; hidden `phone1.conf` remains
  forbidden. Existing desktop WireGuard path/env development inputs must not be
  treated as the product profile-store contract.

## Assumptions

- The first concrete profile type is `wireguard_native_v1`.
- The first import adapter may accept WireGuard `.conf`, but the store must be
  shaped so a later engine can use generated fields, QR/import payloads, or a
  native provider token without pretending to be a `.conf` file.
- Backward compatibility with hidden packaged seed files is not required.
