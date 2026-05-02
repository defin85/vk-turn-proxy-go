## Context

RelayDock already has a structured VPN transport profile editor and store
change in progress. The remaining product gap is not profile editing; it is
native Android VPN lifecycle ownership. The current phone workflow can route
traffic through the external WireGuard Android app, but that path proves only a
compatibility PoC. RelayDock product support requires the packaged app to drive
its own `android_vpn_service` path.

## Goals

- RelayDock owns the Android VPN management UX and lifecycle.
- A stored `wireguard_native_v1` profile plus a resolved TURN artifact can start
  a native `android_vpn_service` session.
- Android permission, resume, stop, status, and diagnostics are exposed through
  the existing host/control-plane model.
- WireGuard/TUN/crypto/transport implementation details may use established
  libraries behind the host/native adapter boundary.
- Acceptance evidence distinguishes RelayDock-native VPN support from the
  external WireGuard-app PoC.
- Android system lifecycle events, including permission revocation, competing
  VPN selection, service stop, foreground notification, and always-on support
  state, are handled explicitly instead of being left as shell-local state.

## Non-Goals

- Reimplement WireGuard cryptography or packet processing from scratch.
- Make `com.wireguard.android` part of the RelayDock product UX.
- Move Android OS VPN primitives into Flutter widgets or shell-local platform
  channels.
- Claim always-on VPN support before the packaged host can start from stored
  state, surface system-started lifecycle, and recover without interactive
  provider resolution.
- Solve unrelated provider browser continuation gaps beyond accepting a
  resolved runtime artifact as startup input.

## Decisions

- Decision: The mobile shell remains a typed control-plane consumer.
  It selects profiles and invokes start/resume/stop actions, but it does not
  own `VpnService`, route programming, socket protection, or native runtime
  attachment.
- Decision: The Android embedded host owns orchestration from structured
  profile and resolved artifact to a ready `android_vpn_service` session.
  It validates prerequisites, materializes runtime inputs, invokes the native
  adapter, and reports lifecycle state.
- Decision: Native libraries are allowed inside the host/native adapter
  implementation boundary.
  Library use is an implementation detail; operator-facing control and
  acceptance remain RelayDock-owned.
- Decision: External WireGuard Android app checks are explicitly excluded from
  product acceptance.
  They can remain documented as a development/compatibility workflow, but a
  green native VPN claim requires direct RelayDock evidence.
- Decision: Always-on VPN is fail-closed until explicitly supported.
  If the current packaged host cannot satisfy Android always-on service
  semantics, the manifest must opt out and product UI must not claim always-on
  behavior. If always-on is later enabled, host startup, state recovery, and
  diagnostics must work when Android starts the service rather than the shell.
- Decision: Current native VPN state is host-owned.
  The shell may cache presentation state, but readiness, stopped, failed,
  revoked, and system-stopped states must be recoverable from the host/control
  plane after shell restart or foreground return.
- Decision: Release package visibility stays narrow.
  RelayDock does not request `QUERY_ALL_PACKAGES` for native VPN app-scope
  routing. Package-scoped policies use operator-provided package names and
  fail closed when Android package visibility or `VpnService.Builder`
  validation cannot prove the package is usable.

## Risks / Trade-offs

- Android VPN permission flow can interrupt startup.
  Mitigation: model startup attempts as resumable and keep shell actions tied
  to the same control-plane attempt.
- Android can revoke a VPN grant, another VPN app can become prepared, or the
  system can stop/restart the service.
  Mitigation: handle native revoke/stop callbacks as lifecycle transitions,
  clean up runtime resources, and expose the resulting state through the host.
- Route, DNS, socket-protection, or app-scope mistakes can break the control
  channel or loop traffic through the VPN itself.
  Mitigation: keep these checks fail-closed in the native adapter/host and
  require startup diagnostics before reporting ready.
- App-scope package selection can push the app toward broad package visibility
  permissions.
  Mitigation: define the minimum package visibility strategy before release and
  treat `QUERY_ALL_PACKAGES` as a policy-sensitive choice requiring explicit
  product/release justification.
- Device evidence can drift from unit-level acceptance.
  Mitigation: add a repo-owned Android smoke that exercises profile save/import,
  permission, ready state, system lifecycle handling, and disconnect without
  external WireGuard UI.

## Migration Plan

1. Close `add-74` as editor/profile-store scope.
2. Implement native lifecycle contract and tests under this change.
3. Keep the existing external WireGuard phone PoC documented as legacy
   compatibility evidence only.
4. Archive this change only after direct device or emulator evidence proves the
   RelayDock-owned native path.
