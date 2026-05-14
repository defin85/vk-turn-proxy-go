# Change: Add optional desktop embedded host backend

## Why

Packaged desktop shells currently depend on launching and negotiating with a
separate loopback `clientd` sidecar process. That keeps the Go host boundary
clean, but it also makes packaged startup sensitive to sidecar placement,
process supervision, local port conflicts, and platform-specific launcher
wrappers. The recent Linux `linux_tun` work shows that ordinary desktop
startup must not be coupled to privilege mediation or brittle process-launch
bridges.

This change explores and introduces an optional embedded desktop host backend:
the desktop GUI can talk to the same Go host contract through a process-local
adapter while keeping the existing loopback `clientd` path as the compatibility,
debug, and rollback surface.

## What Changes

- Add a `desktop-embedded-host` capability contract for process-local desktop
  host execution.
- Keep the client control-plane contract transport-neutral: loopback HTTP and
  embedded adapters expose the same versioned host semantics, capabilities,
  events, diagnostics, provider flows, profile store, and platform-tunnel
  results.
- Let packaged desktop GUI startup prefer a verified embedded host backend
  only when the backend advertises the same required capabilities as the
  sidecar host.
- Preserve the existing sidecar `clientd` path as fallback, development, and
  live-debug infrastructure.
- Preserve native privilege boundaries: Flutter UI code remains a typed
  consumer, and Linux `linux_tun` still reaches privilege only through the
  documented helper path.

## Impact

- Affected specs: `desktop-embedded-host`, `desktop-gui-client`,
  `desktop-platform-tunnel-host-boundary`, `client-control-plane`,
  `native-build-workflows`
- Affected code: desktop Flutter host supervision/control-plane adapter,
  `pkg/clientcontrol` host runner boundaries, desktop package staging,
  platform plugin or FFI bridge, Windows/Linux desktop host wiring, tests
- Migration impact: no existing sidecar or `cmd/clientd` behavior is removed
  in this change. Embedded host startup is additive until packaged parity and
  rollback verification are proven.
