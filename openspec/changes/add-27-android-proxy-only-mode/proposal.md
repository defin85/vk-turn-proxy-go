# Change: [27] Add Android proxy-only mode

## Why
`add-25-android-execution-mode-separation` explicitly says that any future
Android non-system relay path must be a separate runtime mode instead of a
disguised `android_vpn_service` variant.

That umbrella is useful, but it still does not define one concrete
non-system Android mode that the repository could design or ship honestly.

The smallest viable next mode is a proxy-only Android workflow:

- no `VpnService`
- no system-wide capture claim
- explicit app or operator opt-in
- packaged-host-owned local proxy/runtime lifecycle

That gives the product a concrete non-system slice without pretending it is the
same thing as an Android system tunnel.

## Sequence
- Order: `27`
- Depends on: `add-14-android-embedded-mobile-host`, `add-22-runtime-execution-planning`, `add-25-android-execution-mode-separation`
- Unblocks: a first explicit Android non-system runtime workflow that stays separate from `android_vpn_service`

## What Changes
- Add a new `android-proxy-only-mode` capability spec for the first concrete
  non-system Android runtime mode.
- Define a packaged Android proxy-only workflow where Flutter remains the UI,
  the embedded Go host owns local proxy/runtime lifecycle, and Android does not
  claim system-tunnel semantics.
- Define that the first proxy-only mode exposes typed local proxy endpoint
  information and requires explicit app or operator opt-in instead of
  transparent device-wide capture.
- Extend `android-runtime-mode-separation` and
  `runtime-execution-planning` so this mode has its own documented execution
  tuple instead of inheriting `android_vpn_service` semantics.
- Extend `mobile-gui-client` and `client-control-plane` so the shell can render
  the proxy-only workflow, its scope, and its ready/failure state explicitly.

## Impact
- Affected specs: `android-proxy-only-mode` (new), `android-runtime-mode-separation`, `runtime-execution-planning`, `mobile-gui-client`, `client-control-plane`
- Affected code: future Android proxy-only session/runtime wiring, mobile proxy-mode UX, control-plane endpoint metadata, and operator/runtime documentation
