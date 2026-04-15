## Context

The repository now needs two different Android stories:

- an honest system-tunnel story through `android_vpn_service`
- an honest non-system story for cases where the product should not pretend to
  capture all device traffic

The first concrete non-system slice should be explicit and narrow.
If it tries to be a stealth VPN, a fake split tunnel, or a generic umbrella for
every future Android relay, it will blur the execution model again.

The narrowest useful slice is proxy-only mode:

- it does not require `VpnService`
- it does not claim system-wide traffic capture
- it can still reuse the packaged host, typed control plane, and mobile shell

## Goals

- Define one concrete non-system Android mode instead of leaving the umbrella
  abstract
- Keep proxy-only behavior explicit, app-opt-in, and separate from
  `android_vpn_service`
- Keep Flutter as the UI surface and the embedded Go host as the runtime owner
- Require a distinct execution tuple and operator workflow for proxy-only mode

## Non-Goals

- Claiming stealth, anti-detection, or invisibility from Android diagnostics
- Rebranding proxy-only mode as if it were device-wide capture
- Delivering every future Android non-system runtime under one proposal
- Defining provider-specific app integrations for every Android target app

## Decisions

### Decision: The first non-system Android mode is proxy-only

The first concrete non-system Android slice should be an explicit proxy-only
workflow.
That keeps the scope honest and avoids overloading the first non-system mode
with system-tunnel expectations.

### Decision: Proxy-only mode is app-opt-in, not transparent capture

Proxy-only mode must require explicit app or operator opt-in.
If the target app cannot be pointed at the documented local proxy path, the
repository must not imply that the mode still captures that app's traffic.

### Decision: Embedded Go host owns proxy/runtime lifecycle

The packaged embedded Go host should own:

- proxy listener lifecycle
- runtime/session lifecycle
- typed ready/failure state
- endpoint metadata surfaced to the shell

Flutter remains the UI, and Android-native code stays a thin platform adapter
for packaging or platform affordances rather than a second runtime owner.

### Decision: Proxy-only mode needs its own runtime execution tuple

The repository must not reuse the `android_vpn_service` execution tuple for
proxy-only mode.
The non-system mode must appear as its own documented execution plan so shells,
docs, and later implementations can keep scope and detection-surface semantics
separate.

## Risks / Trade-offs

- Proxy-only mode may look less turnkey than a system tunnel because target apps
  must opt in explicitly
- If endpoint metadata is weakly typed, shells may regress into ad hoc copy
  strings instead of a real workflow
- If the execution tuple is underspecified, future proxy-like modes may drift
  back into the same ambiguity that `add-25` tried to prevent

## Validation Plan

- Add the new `android-proxy-only-mode` capability spec
- Extend Android mode-separation and runtime-execution-planning deltas so the
  new mode has a separate tuple and workflow
- Extend mobile GUI and client-control-plane deltas for typed proxy-mode
  endpoint and scope reporting
- `openspec validate add-27-android-proxy-only-mode --strict --no-interactive`
