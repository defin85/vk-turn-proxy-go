## 1. Scope Split and Contract Alignment

- [x] 1.1 Keep `add-74-vpn-transport-profile-editor` closed as structured
      editor/profile-store scope and reference this change for native VPN
      lifecycle acceptance.
- [x] 1.2 Audit existing Android `VpnService`, control-plane, and mobile GUI
      contracts for gaps in start, resume, stop, status, diagnostics, and
      session evidence.
- [x] 1.3 Define fail-closed acceptance criteria that external WireGuard
      Android app checks do not satisfy product VPN management.
- [x] 1.4 Define Android system lifecycle acceptance for permission revocation,
      competing VPN selection, foreground notification, service stop/restart,
      and always-on support or explicit always-on opt-out.

## 2. Control Plane and Host Lifecycle

- [x] 2.1 Ensure startup requests can reference the selected structured profile
      and resolved TURN/session artifact without exposing raw secret material
      to Flutter shell state.
- [x] 2.2 Implement and verify Android host materialization from structured
      `wireguard_native_v1` profile into the native `android_vpn_service`
      attach path.
- [x] 2.3 Implement and verify resume after Android VPN permission grant,
      cancellation, and denial handling.
- [x] 2.4 Implement and verify disconnect/stop teardown for both the runtime
      session and native `VpnService` resources.
- [x] 2.5 Surface current native VPN lifecycle state, selected scope, session
      link, and actionable diagnostics through the control plane.
- [x] 2.6 Make host-reported lifecycle state recoverable after shell restart,
      app foreground return, Android service stop, or VPN permission revocation
      instead of relying only on shell-local startup results.

## 3. Native Adapter Boundary

- [x] 3.1 Keep Android VPN permission, TUN creation, routes, DNS,
      socket-protection, and app-scope policy inside the host/native adapter
      boundary.
- [x] 3.2 Use library-backed WireGuard/TUN/crypto/transport components behind
      the host boundary without adding a third-party operator UI dependency.
- [x] 3.3 Fail closed when profile, TURN artifact, route policy, DNS bypass,
      app scope, native library, or runtime attach prerequisites are missing.
- [x] 3.4 Handle Android `VpnService` revocation, `Builder.establish()` null,
      competing VPN app selection, and system stop as cleanup-producing
      lifecycle transitions.
- [x] 3.5 Define the release package-visibility strategy for app-scope
      selection; keep `QUERY_ALL_PACKAGES` only with explicit justification or
      replace it with narrower `<queries>`/operator-provided package handling.

## 4. Mobile UX

- [x] 4.1 Drive setup, start, permission resume, ready, diagnostics,
      disconnect, and error recovery from the RelayDock mobile UI.
- [x] 4.2 Keep external WireGuard app workflows out of product UI and
      acceptance copy for native VPN management.
- [x] 4.3 Show active state, selected scope, session identity, and diagnostics
      in the main mobile workflow without requiring a separate support-only
      screen for basic control.

## 5. Verification

- [x] 5.1 Add Go tests for structured profile to `android_vpn_service`
      materialization, startup, failure, and cleanup.
- [x] 5.2 Add Flutter controller/widget tests for native setup, start, resume,
      disconnect, status, diagnostics, and external-WireGuard exclusion.
- [x] 5.3 Add a repo-owned Android device or emulator smoke for profile
      save/import to permission to ready session to disconnect, with no
      `com.wireguard.android` dependency in the path.
- [x] 5.4 Cover permission denial, permission revocation, competing VPN
      selection, service stop, always-on opt-out/support state, foreground
      notification presence, and package-scope validation in targeted tests or
      device checks.
- [x] 5.5 Run targeted Go and Flutter verification for touched packages.
- [x] 5.6 Run
      `openspec validate add-75-relaydock-native-vpn-management --strict --no-interactive`.
