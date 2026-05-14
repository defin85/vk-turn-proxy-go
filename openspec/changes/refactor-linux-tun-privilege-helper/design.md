## Context

The existing Linux package made `linux_tun` available by launching the bundled
`clientd` as root through a shell wrapper. That shortcut validated that the
native Linux TUN lifecycle can work, but it placed too much product behavior
inside a root process:

- `/v1/host` and the whole local control plane
- provider resolution and browser-assisted continuation
- VPN transport-profile store access
- runtime execution-plan and lease materialization
- desktop-environment variables needed to launch Chrome

The existing OpenSpec contract already points to a narrower boundary:
`desktop-platform-tunnel-host-boundary` says Linux helpers receive only
ephemeral execution inputs, and `desktop-sidecar-host` says Linux desktop hosts
should acquire native privilege through a repo-owned helper instead of making
the Flutter shell privileged. This change tightens that contract so the
desktop host itself also stays unprivileged.

## Goals

- Make ordinary RelayDock desktop startup independent of Linux privilege
  acquisition.
- Keep VK/provider browser continuation in the operator's user session.
- Keep VPN transport-profile persistence user-space and host-owned.
- Restrict the privileged Linux process to native tunnel work for one
  startup attempt.
- Surface helper denial, helper startup failure, route failure, runtime attach
  failure, and cleanup failure through the canonical typed platform-tunnel
  startup result.
- Keep the first supported target Ubuntu-package-specific and fail-closed for
  other Linux targets.

## Non-Goals

- Designing a cross-distro service manager for all Linux desktops.
- Adding a second public helper API for the Flutter shell.
- Moving provider resolution or profile storage into the helper.
- Changing Windows, Android, or generic TURN behavior.
- Supporting snap Chromium as the preferred browser-continuation runtime.

## Current Problem

The current runtime path is:

```text
Flutter GUI
  -> /opt/relaydock/clientd shell launcher
  -> pkexec or sudo -A
  -> /opt/relaydock/libexec/relaydock-clientd-linux-tun
  -> /opt/relaydock/libexec/clientd as root
  -> provider/browser/profile/control-plane/platform-tunnel work
```

This makes the auth prompt part of local-host discovery. If privilege
mediation fails or the prompt is hidden, the GUI cannot connect to any host.
The shell reports `Local host blocked` even though only `linux_tun` privilege
is missing.

It also forces browser continuation into root:

- Chrome starts with root-owned profile state.
- Snap Chromium wrappers are unreliable across root/user desktop boundaries.
- Xauthority, Wayland, DBus, and cookie/session state must be bridged through
  ad hoc environment files.

## Target Architecture

The target runtime path is:

```text
Flutter GUI
  -> /opt/relaydock/clientd unprivileged launcher
  -> /opt/relaydock/libexec/clientd as the operator user
     - owns /v1/host
     - owns profiles, resolutions, browser continuation, sessions
     - materializes a WireGuard TURN execution lease
     - invokes privileged helper only for linux_tun startup/cleanup
  -> pkexec /opt/relaydock/libexec/relaydock-linux-tun-helper
     - receives one ephemeral startup payload
     - owns native TUN/routes/DNS/runtime attach/dataplane probe/cleanup
     - returns typed result details to unprivileged clientd
```

## Boundary Decisions

### User-space `clientd` is the canonical local host

The GUI discovers and supervises the local host exactly as it does on other
desktop targets. Starting `/opt/relaydock/clientd` must not trigger `pkexec`,
`sudo`, or a password prompt. A missing privilege mediator must not prevent
`/v1/host`, provider catalog, provider resolution, profile editing, or
diagnostics from working.

### The privileged helper owns only Linux-native tunnel lifecycle

The helper may create or configure native resources for one `linux_tun`
attempt:

- TUN device creation and teardown
- interface address and MTU setup
- route and DNS bypass preparation
- strict WireGuard TURN runtime attach when that attach needs the native TUN
  handle
- dataplane probe execution and evidence collection
- cleanup for partial or active native state

The helper must not:

- listen on the local control-plane port
- read or write the VPN transport-profile store
- resolve providers or start browser continuation
- inspect shell persistence
- accept arbitrary file paths or shell commands from the GUI

### Helper lifetime is active-attempt scoped and host-supervised

The helper is not a second local control-plane daemon and is not a public
service. For the supported implementation where the helper owns the TUN handle
and strict WireGuard TURN runtime attach, the helper lifetime is tied to the
active startup attempt and any resulting active tunnel.

The unprivileged host owns the attempt id, the helper process/client handle,
and the cleanup decision. Only one active native `linux_tun` attempt may own
native state at a time. Stop/cleanup requests flow through the host-owned
helper client, and helper crash or host crash is reconciled as a typed
platform-tunnel failure or cleanup state rather than as a local-host failure.

If a later implementation can safely pass all native ownership back to the
unprivileged host, it must keep the same attempt-scoped result and cleanup
contract.

### Transport profile persistence stays user-space

The packaged Linux local host reads and writes VPN transport profiles from the
operator user's host-owned profile store. The privileged helper never receives
profile-store paths, raw profile records, or long-lived profile identifiers as
execution authority. It receives only the materialized ephemeral execution
lease selected by the unprivileged host for the current attempt.

Any legacy root-owned package store created by the broad root-host launcher is
handled as a one-time migration or setup-needed diagnostic. After a successful
migration, startup uses the user-space profile id. If migration is impossible
or ambiguous, the host reports the transport-profile prerequisite explicitly;
it does not keep `/var/lib/relaydock/.../store.json` as a parallel live store.

### The helper protocol is private and schema-bound

The helper protocol is package-internal. The shell never calls it directly.
The unprivileged host sends a structured startup payload containing only:

- protocol/schema version and helper compatibility identity
- startup attempt id and attempt nonce
- mode and selected execution plan
- materialized `WireGuardTurnExecutionLease`
- route/DNS policy directives
- cleanup handle or attempt-scoped helper identity

The helper rejects missing, unknown, duplicate, stale, oversized, or mismatched
fields fail-closed. It must never source shell code or trust arbitrary
environment variables as execution inputs. Helper logs and diagnostics must
redact transport secrets, provider material, and profile-store paths.

### Privilege mediation is helper-only in the normal product path

The normal `/opt/relaydock/clientd` launcher must not invoke `pkexec`, `sudo`,
or an askpass helper. Polkit/pkexec mediation is acceptable only for executing
the narrow helper artifact during a platform-tunnel startup attempt. A
`sudo -A` path, if retained, is a documented legacy/debug fallback and not the
ordinary GUI startup path. If no prompt can be completed, the host reports the
typed helper permission failure while keeping `/v1/host` available.

### Permission is a startup stage

`linux_tun` support can be advertised when the packaged Ubuntu host and helper
are installed and prerequisites are discoverable. Actual elevation is acquired
when the operator starts `linux_tun`. If elevation is denied or unavailable,
the control plane returns `ready=false`, `stage=permission_acquire`, and
`missing_prerequisite=permission`.

Capability metadata must not claim the `permission` prerequisite as satisfied
before helper privilege acquisition succeeds for an attempt. Installed-helper
support and permission acquisition are separate facts.

## Implementation Strategy

1. Split the current Linux wrapper into two package artifacts:
   - `/opt/relaydock/clientd`: unprivileged launcher for `libexec/clientd`
   - `/opt/relaydock/libexec/relaydock-linux-tun-helper`: privileged helper
2. Update `cmd/clientd` Linux host wiring so non-root Linux package hosts are
   compatible and can negotiate ordinary control-plane capabilities.
3. Refactor `internal/linuxdesktophost` so route policy validation and lease
   materialization happen in the unprivileged host, while native operations
   move behind a helper client interface.
4. Move packaged Linux profile-store ownership back to the operator user's
   store and add a reviewed migration/setup-needed path for any legacy
   root-owned package store.
5. Add helper protocol tests and fake-helper integration tests for denial,
   malformed payloads, partial cleanup, and ready-path success.
6. Update Ubuntu packaging and docs to install separate launcher/helper/polkit
   artifacts and to remove the root `clientd` env bridge from the normal path.
7. Verify the installed Ubuntu package by proving `/v1/host` is reachable
   before any privilege prompt, then proving `linux_tun` startup prompts only
   at platform-tunnel start.

## Risks

- Helper protocol scope creep could recreate root `clientd` under another
  name. Keep the schema narrow and test that provider/profile fields are
  rejected.
- Helper cleanup has to be robust across clientd exit, helper exit, and failed
  startup after partial native state.
- Polkit behavior varies by desktop environment. This change mitigates that by
  making polkit affect only `linux_tun` startup, not ordinary RelayDock host
  availability.
- Transport-profile store ownership may need migration from root-owned
  package state to user-space host state.

## Validation Plan

- `openspec validate refactor-linux-tun-privilege-helper --strict --no-interactive`
- Unit tests for helper payload validation and permission-denial mapping
- Go tests for `internal/linuxdesktophost`, `pkg/clientcontrol`, and
  `cmd/clientd`
- Desktop host supervisor/widget tests proving compatible local host startup
  does not require elevation
- Linux package build verification proving separate launcher/helper/polkit
  artifacts are staged
- Installed Ubuntu smoke:
  - `/opt/relaydock/clientd -listen 127.0.0.1:7777` reaches `/v1/host` as
    the operator user without a password prompt
  - the packaged profile store is operator-owned, and legacy root-owned
    package state is migrated once or reported as setup-needed
  - provider browser continuation starts as the operator user
  - `POST /v1/platform-tunnels/start` is the first operation that asks for
    Linux privilege
  - privilege denial returns typed platform-tunnel failure while `/v1/host`
    remains reachable
  - helper crash during an active attempt produces typed tunnel state and does
    not require restarting RelayDock to recover the local host
