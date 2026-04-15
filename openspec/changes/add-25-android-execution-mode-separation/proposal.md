# Change: [25] Add Android execution mode separation

## Why
`add-17-android-vpn-service-ready-path` is the honest Android system-tunnel
slice.
That path can support real `VpnService` startup and explicit per-app routing,
but it should not be overloaded with stealth expectations that do not match the
Android platform contract.

If the product later needs a different Android detection surface, a different
operator workflow, or app-opt-in relay behavior, that work must appear as an
explicitly different Android execution mode instead of as a disguised variant
of `android_vpn_service`.

## Sequence
- Order: `25`
- Depends on: `add-17-android-vpn-service-ready-path`, `add-22-runtime-execution-planning`
- Unblocks: future Android proxy-only, app-opt-in relay, or other non-system-tunnel mode proposals with explicit detection-surface review

## What Changes
- Add a new `android-runtime-mode-separation` capability spec that distinguishes
  Android system-tunnel `android_vpn_service` behavior from future non-system
  Android relay modes.
- Define that `android_vpn_service` remains a documented Android system tunnel
  mode and must not be marketed or described as hidden from Android
  diagnostics.
- Define that any future Android proxy-only, app-opt-in relay, or reduced
  detection-surface mode must use a separate runtime execution plan and a
  separate operator-facing workflow instead of piggybacking on
  `android_vpn_service`.
- Extend runtime execution planning and mobile GUI requirements so the app can
  present Android system-tunnel and non-system modes as distinct choices with
  different scope and risk surfaces.
- Require an explicit threat-model and evidence review before any future change
  may claim a smaller Android detection surface than the honest `VpnService`
  path.

## Impact
- Affected specs: `android-runtime-mode-separation` (new), `mobile-gui-client`, `runtime-execution-planning`
- Affected code: future Android shell/workflow UX, runtime-execution-plan reporting, future Android non-system relay paths, and operator/runtime documentation
