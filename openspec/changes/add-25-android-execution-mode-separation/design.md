## Context

The repository now has two relevant Android planning pressures:

- `add-17` defines the first real Android `VpnService` path
- product discussion also wants app-scoped routing and a potentially different
  Android detection surface

Those are not the same problem.
`VpnService` is an Android system-tunnel primitive.
If the repository later needs a different detection surface or a manual
app-opt-in relay workflow, that should be modeled as a different Android mode,
not as a hidden variant of the same system-tunnel mode.

This mirrors a pattern used by existing Android networking apps that separate
VPN mode from proxy-only mode instead of pretending they are the same runtime.

## Goals

- Keep Android system-tunnel behavior explicit and honest
- Define a framework for future Android non-system relay modes without forcing
  them into the `android_vpn_service` contract
- Keep mode-specific detection-surface claims explicit and reviewable
- Ensure mobile UX can present mode differences without hiding scope or risk

## Non-Goals

- Implementing stealth or diagnostic-evasion behavior
- Delivering a specific proxy-only or foreign-core runtime in this change
- Weakening `add-17` by redefining `android_vpn_service` as something other
  than an Android system tunnel
- Claiming that one non-system mode is automatically safer or less detectable
  before explicit review and evidence

## Decisions

### Decision: `android_vpn_service` remains the honest system-tunnel mode

The repository should treat `android_vpn_service` as a real Android system
tunnel with platform-visible semantics.
Future product or operator language must not describe that mode as hidden from
Android diagnostics.

### Decision: Future non-system Android modes must be separate execution plans

If the repository later adds a proxy-only, app-opt-in relay, or other
non-system Android runtime, that path must use its own execution plan, carrier
ownership, and operator-facing workflow.
It must not reuse the `android_vpn_service` plan just because the user-facing
goal sounds similar.

### Decision: Detection-surface claims require explicit threat-model review

Any future Android proposal that claims a smaller or different detection
surface than `android_vpn_service` must carry an explicit threat model,
acceptance criteria, and evidence requirements.
That review should stay separate from the first honest VPN mode rollout.

### Decision: Mobile UX must separate mode scope clearly

If multiple Android runtime modes exist later, the mobile shell should present
them as different modes with different capture scope, app opt-in requirements,
and operational constraints.
The UI must not collapse them into one generic "protection" toggle.

## Risks / Trade-offs

- Creating explicit mode separation adds UX and documentation complexity
- Teams may still try to overload `android_vpn_service` because it already owns
  packet capture
- A vague future non-system mode could drift into foreign-core or stealth work
  without proper review if the boundaries are not explicit

## Validation Plan

- Add a new `android-runtime-mode-separation` capability spec
- Extend runtime execution planning and mobile GUI specs so Android system and
  non-system modes stay distinct
- Require threat-model and evidence gates for any future Android mode that
  claims a different detection surface than `android_vpn_service`
- `openspec validate add-25-android-execution-mode-separation --strict --no-interactive`
