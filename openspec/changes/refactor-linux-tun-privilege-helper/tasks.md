## 1. Contract and host boundary
- [x] 1.1 Update Linux host capability wiring so a packaged Ubuntu user-space
      `clientd` can negotiate the local control plane without root.
- [x] 1.2 Move `linux_tun` permission acquisition from host startup into the
      platform-tunnel startup path.
- [x] 1.3 Keep provider resolution, browser continuation, profile store access,
      execution-plan selection, and execution-lease materialization in
      unprivileged `clientd`.
- [x] 1.4 Move packaged Linux transport-profile persistence to the operator
      user's host-owned store, with legacy root-owned package state handled
      only through one-time migration/import or explicit setup-needed
      diagnostics.
- [x] 1.5 Stop reporting the `permission` prerequisite as satisfied before a
      helper startup attempt has actually acquired Linux privilege.

## 2. Privileged helper protocol
- [x] 2.1 Add a repo-owned Linux TUN helper command and package-internal
      helper protocol.
- [x] 2.2 Define strict request/response schemas for startup, status, and
      cleanup payloads.
- [x] 2.3 Reject provider identifiers, profile-store paths, browser settings,
      arbitrary file paths, and unknown command fields at the helper boundary.
- [x] 2.4 Map helper denial, malformed payloads, helper exit, native startup
      failure, runtime attach failure, dataplane failure, and cleanup failure
      to typed platform-tunnel results.
- [x] 2.5 Include protocol/schema versioning, helper compatibility identity,
      attempt id, attempt nonce, payload size limits, strict unknown-field
      rejection, and redacted diagnostics in the helper protocol.
- [x] 2.6 Reject stale, duplicate, or overlapping helper attempts fail-closed
      without creating additional native `linux_tun` state.

## 3. Linux lifecycle refactor
- [x] 3.1 Split `internal/linuxdesktophost` into unprivileged orchestration and
      privileged native-operation client interfaces.
- [x] 3.2 Move TUN creation, route/DNS application, native cleanup, and
      native dataplane probe ownership behind the helper interface.
- [x] 3.3 Ensure stop/cleanup remains host-owned even if helper startup failed
      after partial native state.
- [x] 3.4 Ensure concurrent startup attempts cannot create overlapping
      `linux_tun` native state.
- [x] 3.5 Define the helper lifetime as active-attempt scoped and
      host-supervised, including the case where the helper owns the active TUN
      handle and WireGuard TURN runtime attach.
- [x] 3.6 Reconcile helper crash, clientd crash, and stale native interface
      state into typed tunnel/cleanup state while keeping `/v1/host`
      reachable.

## 4. Packaging and docs
- [x] 4.1 Replace the normal Linux `clientd` launcher with an unprivileged
      launcher.
- [x] 4.2 Stage the privileged helper and its polkit metadata as separate
      package artifacts.
- [x] 4.3 Remove the normal-path root `clientd` env bridge and document any
      remaining legacy/debug-only path separately.
- [x] 4.4 Update `docs/linux-desktop-tun-package.md` and agent docs with the
      new launch and verification runbook.
- [x] 4.5 Remove normal-path package exports that force the user-space host to
      use a root-owned transport-profile store.
- [x] 4.6 Verify polkit metadata authorizes only the helper artifact path, not
      `/opt/relaydock/clientd` or `libexec/clientd`.
- [x] 4.7 If a `sudo -A` askpass path remains, keep it behind explicit
      legacy/debug documentation and out of ordinary GUI host startup.

## 5. UI and diagnostics
- [x] 5.1 Keep `Local host blocked` reserved for failure to start or negotiate
      the user-space local host.
- [x] 5.2 Render Linux privilege denial as a platform-tunnel startup failure
      with retry, not as host incompatibility.
- [x] 5.3 Include helper-stage diagnostics in the existing diagnostics/export
      surface without exposing a shell-callable helper API.

## 6. Verification
- [x] 6.1 Add unit tests for helper payload validation and typed failure
      mapping.
- [x] 6.2 Run `go test ./internal/linuxdesktophost ./pkg/clientcontrol ./cmd/clientd`.
- [x] 6.3 Run desktop GUI tests covering local-host startup and Linux
      permission-denial UX.
- [x] 6.4 Run `make build-gui-linux` and `make package-gui-linux-deb`.
- [x] 6.5 Verify on Ubuntu package install that `/v1/host` is reachable before
      any privilege prompt.
- [x] 6.6 Verify on Ubuntu that browser continuation starts as the operator
      user, not root.
- [x] 6.7 Verify on Ubuntu that `linux_tun` startup is the first operation that
      invokes the privileged helper.
- [x] 6.8 Verify privilege denial keeps `/v1/host` reachable and returns
      `permission_acquire`/`permission`.
- [x] 6.9 Verify helper crash and stale `rdtun0` or route state can be
      reconciled without converting the local host to `Local host blocked`.
- [x] 6.10 Verify legacy root-owned transport-profile store state is migrated
      once or reported as setup-needed, and is not used as a live second store.
- [x] 6.11 Run `openspec validate refactor-linux-tun-privilege-helper --strict --no-interactive`.
