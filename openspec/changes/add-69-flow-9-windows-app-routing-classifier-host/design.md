## Context

Windows desktop app routing needs more than a Wintun interface.
Wintun can carry packets once a route sends traffic to the adapter, but a route
does not identify the originating application.
To behave like a desktop per-app routing tool, the host needs a classifier or
equivalent enforcement layer that can map outbound traffic to a Windows
application identity and apply the selected policy.

## Goals

- Make Windows the first concrete desktop app-routing implementation target
- Keep app classification and privileged enforcement inside the Windows host
  boundary
- Require a verified process-to-flow mapping before support is advertised
- Keep unknown or unenforceable identities fail-closed
- Produce repeatable smoke evidence for routed and non-routed Windows apps

## Non-Goals

- Selecting one Windows filtering technology in the spec before a feasibility
  spike has evidence
- Shipping app routing for Linux or macOS in this change
- Moving app classification into Flutter
- Treating a route-table-only `windows_wintun` startup as app routing
- Defining live selector mutation for an already-ready tunnel

## Decisions

### Decision: The Windows host owns classification and enforcement

The packaged Windows host owns app inventory, app identity resolution,
process-to-flow classification, policy enforcement, and cleanup.
The control plane owns typed requests and startup state.
The desktop shell consumes inventory and status only.

### Decision: Support starts unavailable until enforcement evidence exists

The Windows host must keep desktop app routing unavailable until it can prove
that selected app traffic follows the requested route policy and that
non-selected traffic is not silently widened into the tunnel.

### Decision: Candidate mechanisms are implementation choices

The implementation may evaluate Windows filtering, packet diversion, or an
explicit proxy/adapter layer.
The spec should require observable behavior and cleanup guarantees, not encode
one Windows API name into the cross-platform contract.

### Decision: Unknown flow handling must be policy-aware

If the host cannot attribute a flow to an enforceable app identity, it must not
silently widen the app-routing scope.
The host must document and report how unknown flows are handled for each policy
kind before advertising support.

## Risks / Trade-offs

- Windows filtering can require elevated privileges, driver packaging, signing,
  or service lifecycle work beyond the current Wintun path.
- Process-to-flow attribution can be ambiguous for system services, browser
  child processes, helper executables, or packaged applications.
- A diversion/proxy approach can behave differently from a kernel filtering
  approach and needs explicit compatibility evidence.
- False positives are worse than unavailable support: routing the wrong app
  undermines the operator's trust in app routing.

## Validation Plan

- Add Windows-specific requirements under `desktop-application-routing` and
  `platform-tunnel-integration`.
- Implement future host tests that reject support claims without classifier
  evidence.
- Add a Windows smoke that proves selected app routing and non-selected app
  exclusion on the same host.
- Validate with:
  `openspec validate add-69-flow-9-windows-app-routing-classifier-host --strict --no-interactive`
