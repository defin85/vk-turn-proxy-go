## Context

The repository already has one concrete packaged desktop path through
`windows_wintun`, where the packaged desktop host owns driver checks, route
preparation, runtime attach, dataplane verification, and teardown.

Linux currently has none of that:

- `cmd/clientd/host_nonwindows.go` still returns the generic fallback host
- `/v1/host` on Linux reports `linux_tun available=false` with
  `missing_prerequisite=host_implementation`
- the repository has userspace WireGuard-over-TURN runtime code, but no
  packaged Linux host that owns TUN, route, or privilege mediation

The first Linux product slice should not make the entire desktop host
privileged. It also should not force the Flutter shell to orchestrate native
network state directly.

## Goals

- Define a Linux packaged-host ownership boundary that matches the desktop
  family contract already established for Windows.
- Keep provider resolution, transport-profile materialization, and ordinary
  control-plane state inside the unprivileged Go host.
- Allow Linux native TUN and route work to use a repo-owned privileged helper
  without creating a second public startup API.
- Keep `linux_tun` support unavailable until later changes deliver the ready
  path and packaging/install surface.

## Non-Goals

- Delivering a `ready=true` Linux path in this change.
- Choosing the final Ubuntu packaging artifact or installer shape.
- Broad cross-distro privilege mediation beyond the first documented Ubuntu
  path.

## Decisions

### Decision: Linux gets a dedicated packaged host instead of the generic non-Windows fallback

The Linux product path should move from the generic `clientcontrol.New`
fallback into a dedicated `internal/linuxdesktophost` package, mirroring the
separation already used for Windows and Android packaged hosts.

### Decision: Privileged Linux work stays in a narrow helper, not in the whole host

The first Linux product slice should not require the entire `clientd` host to
run as root or with broad ambient capabilities. Instead, the packaged Linux
host should launch a repo-owned helper that is responsible only for native
network primitives such as:

- creating or attaching the TUN device
- applying route and DNS policy
- cleaning up Linux-native state

### Decision: The privileged helper receives only ephemeral execution inputs

The unprivileged host remains the owner of:

- provider resolution
- transport-profile selection and validation
- execution-plan selection
- `WireGuardTurnExecutionLease` materialization

The privileged helper may receive only the ephemeral execution lease and the
host-owned route policy directives required for one startup attempt. It must not
own the transport-profile store, provider state, or shell persistence.

### Decision: Linux privilege mediation is repo-owned and typed

The helper launch path should stay repo-owned rather than asking the operator to
start RelayDock through `sudo` manually. The first documented mediation path can
be Ubuntu-oriented and use a repo-owned `pkexec`/polkit flow, but that
mechanism stays behind the desktop host boundary and must report typed startup
results back through the canonical control plane.

### Decision: Helper failure does not become a second desktop API

Privilege denial, helper startup failure, or helper cleanup failure should
surface through the canonical `/v1/platform-tunnels/start` typed result rather
than through shell-local heuristics or helper-specific UI logic.

## Risks / Trade-offs

- A helper process adds one more moving part and packaging surface.
- A Linux helper that is too broad will become a root-shaped copy of `clientd`,
  which would weaken the intended boundary.
- Different Linux desktop environments may behave differently around privilege
  prompts; the first change must therefore stay narrow and Ubuntu-first.

## Validation Plan

- Strict OpenSpec validation for this change.
- Future implementation must prove that Linux helper denial and cleanup failures
  still surface only through the canonical desktop control-plane startup API.
