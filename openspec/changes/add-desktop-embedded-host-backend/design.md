## Context

The current desktop shell talks to `cmd/clientd` over a loopback HTTP control
plane. That sidecar path is simple to test, mirrors operator CLI workflows, and
keeps runtime failures outside the Flutter process. It also adds packaged
startup friction: the GUI has to discover a sibling binary, launch it, wait for
negotiation, manage shutdown, and distinguish real host incompatibility from
launcher or port failures.

The embedded-host direction is attractive only if it removes sidecar process
fragility without deleting the host/control-plane architecture. The product
should not move provider resolution, transport-profile persistence, runtime
execution planning, native tunnel bring-up, or privileged cleanup into Flutter
UI code.

## Goals

- Let packaged desktop builds use an optional process-local host backend.
- Preserve one canonical host contract across sidecar and embedded backends.
- Keep the Flutter shell a typed consumer of host state.
- Keep `cmd/clientd` available for development, diagnostics, automation,
  fallback, and remote/live debugging.
- Start with one conservative desktop target before enabling broad desktop
  rollout.

## Non-Goals

- Removing `cmd/clientd`.
- Removing the loopback HTTP control-plane contract.
- Moving Go provider/runtime/native tunnel logic into Dart.
- Letting Flutter UI code manipulate OS tunnel primitives directly.
- Replacing the Linux privileged helper with GUI elevation.
- Making embedded mode mandatory for all desktop platforms in the first slice.

## Design Decisions

### Embedded host is a backend, not a new product contract

The shell-facing abstraction remains `ControlPlaneApi`. The embedded backend
implements that abstraction without requiring localhost HTTP for packaged
startup. It must expose the same version, capabilities, errors, event stream,
diagnostics, provider descriptors, profile lifecycle, transport-profile store,
and platform-tunnel semantics as the loopback sidecar.

Any embedded-only behavior is treated as a compatibility bug unless it is
explicitly represented in host capabilities and accepted by the shell.

### Sidecar remains the safety valve

The sidecar path stays supported. Packaged builds may choose embedded mode only
after capability negotiation succeeds. If embedded initialization fails before
the host is compatible, the shell can fall back to the existing sidecar
supervision path and report the backend decision in diagnostics.

This keeps `go run ./cmd/clientd`, packaged sibling `clientd`, and loopback
smokes useful while the embedded host matures.

### Native tunnel ownership remains host-owned

The embedded backend may host the Go control plane inside the GUI process, but
that does not make the GUI the owner of native tunnel primitives. The host
boundary still owns driver/TUN/route/DNS/runtime attach semantics, and OS
privilege remains behind platform-specific host or helper code.

For Linux, embedded mode must not run `linux_tun` privileged work in the GUI
process. The documented helper boundary remains the privilege path.

### Crash isolation is an explicit rollout gate

Embedding the host removes process isolation. A panic, cgo crash, or native
adapter fault can take down the GUI. The first implementation must therefore
define recovery and rollback behavior before it is considered a production
default. The initial target should be the least risky desktop path, with Linux
left on sidecar/helper mode until its privilege boundary is stable.

## Implementation Shape

1. Extract the host/control-plane core into a reusable runner that can be
   served either over loopback HTTP or through an embedded adapter.
2. Add a desktop `HostSupervisor` backend selection model:
   embedded first when enabled and compatible, sidecar fallback otherwise.
3. Add an embedded control-plane adapter in Flutter using the chosen platform
   bridge, while keeping `ControlPlaneApi` as the only shell-facing surface.
4. Prove parity with sidecar through shared contract tests.
5. Package the embedded host backend for one desktop target and keep sibling
   `clientd` staged until rollback and diagnostics evidence are strong.

## Risks

- Embedded Go/native crashes can terminate the Flutter app.
- FFI or platform-plugin packaging may be more complex than a sibling binary.
- Long-running event streams and cancellation semantics can drift from HTTP.
- Debuggability can regress if loopback `clientd` is removed too early.
- Linux privilege handling can regress if embedded mode bypasses the helper
  boundary.

## Open Questions

- Which desktop target should be the first embedded backend proof: Windows or
  Linux without `linux_tun` enabled?
- Should the first bridge be FFI/shared library or a platform plugin that owns
  native process-local calls?
- Should packaged embedded mode be behind an operator/debug feature flag until
  multiple release smokes pass?
