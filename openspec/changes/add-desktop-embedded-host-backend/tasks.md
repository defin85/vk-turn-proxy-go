## 1. Contract and architecture
- [ ] 1.1 Define the embedded desktop host capability and backend-selection
      contract without removing the loopback sidecar path.
- [ ] 1.2 Keep `ControlPlaneApi` as the only Flutter-facing host abstraction
      and document transport-neutral parity requirements.
- [ ] 1.3 Define backend diagnostics that report embedded initialization,
      fallback, host build identity, and control-plane contract version.
- [ ] 1.4 Define the first supported embedded target and keep other desktop
      targets fail-closed or sidecar-only.

## 2. Host runner and adapter boundary
- [ ] 2.1 Extract reusable Go host runner lifecycle from `cmd/clientd` so the
      same host can be driven by loopback HTTP or an embedded adapter.
- [ ] 2.2 Add an embedded host adapter that exposes host operations, event
      streaming, cancellation, and shutdown through the selected desktop bridge.
- [ ] 2.3 Keep provider resolution, profile storage, runtime execution
      planning, and platform-tunnel startup inside the Go host boundary.
- [ ] 2.4 Preserve the loopback HTTP `cmd/clientd` path and its existing
      contract tests.

## 3. Desktop shell integration
- [ ] 3.1 Add desktop host backend selection to the shell supervisor:
      embedded when enabled and compatible, sidecar fallback otherwise.
- [ ] 3.2 Implement embedded `ControlPlaneApi` parity for host info,
      negotiation, providers, profiles, transport profiles, resolutions,
      sessions, challenges, diagnostics, events, and platform tunnels.
- [ ] 3.3 Ensure local shell state rehydration works the same through embedded
      and sidecar backends.
- [ ] 3.4 Ensure embedded backend failures do not get reported as unrelated
      provider, profile, or platform-tunnel failures.

## 4. Native tunnel and privilege boundaries
- [ ] 4.1 Prove the embedded backend keeps Flutter UI code out of OS tunnel
      primitive lifecycle, route manipulation, DNS changes, and cleanup.
- [ ] 4.2 Keep Linux `linux_tun` privilege acquisition behind the documented
      helper boundary; embedded mode must not require the GUI process to run
      as root.
- [ ] 4.3 Preserve Windows `windows_wintun` host ownership and stage-aware
      startup results under the same control-plane contract.

## 5. Packaging and rollback
- [ ] 5.1 Update the native desktop packaging workflow for the first embedded
      target to stage required bridge/library/plugin artifacts.
- [ ] 5.2 Keep a compatible `clientd` sidecar staged for rollback until
      embedded mode has documented parity and live smoke evidence.
- [ ] 5.3 Add package verification that fails when embedded artifacts are
      missing, mismatched, or advertise incompatible host capabilities.
- [ ] 5.4 Document operator/debug controls for forcing sidecar mode and
      collecting embedded backend diagnostics.

## 6. Verification
- [ ] 6.1 Add shared control-plane contract tests that run against both
      loopback sidecar and embedded adapters.
- [ ] 6.2 Run targeted Go tests for `pkg/clientcontrol`, `cmd/clientd`, and
      the affected desktop host package.
- [ ] 6.3 Run desktop Flutter tests covering backend selection, embedded
      success, embedded fallback, and incompatible embedded host states.
- [ ] 6.4 Run the first-target package build and verify embedded artifacts plus
      sidecar fallback are staged.
- [ ] 6.5 Capture a packaged desktop smoke proving embedded startup reaches
      `/v1/host`-equivalent negotiated readiness without launching sidecar.
- [ ] 6.6 Capture a fallback smoke proving sidecar mode still works when
      embedded mode is disabled or initialization fails.
- [ ] 6.7 Run `openspec validate add-desktop-embedded-host-backend --strict --no-interactive`.
