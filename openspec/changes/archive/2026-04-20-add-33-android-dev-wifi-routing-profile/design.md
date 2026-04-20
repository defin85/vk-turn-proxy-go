## Context

The packaged Android VPN path now supports real `android_vpn_service` startup
and explicit per-app routing.
That solves user-facing scope selection, but it does not fully solve
development-time local-network reachability.

Today the Android host:

- already protects the runtime socket from re-entering the VPN
- already supports app-routing policies (`all_apps`, `allowed_packages`,
  `disallowed_packages`)
- already performs a partial hidden IPv4 route subtraction for some policies

That is not enough for a reliable Wi-Fi debug loop because app-routing controls
which app traffic enters the tunnel, while wireless debugging and local bridge
reachability depend on underlay-network routing.

This change therefore needs a separate routing-profile axis inside the existing
`android_vpn_service` mode.
It must not create a new Android runtime mode, because `add-25` already
requires future non-system Android modes to be modeled as separate execution
plans rather than hidden variants of the system-tunnel path.

## Goals

- Keep `android_vpn_service` as the same honest Android system-tunnel mode
- Introduce one explicit development-oriented routing profile for preserving the
  active local underlay network
- Keep app-routing and underlay-route preservation as separate typed concerns
- Fail closed when the requested development profile cannot be prepared safely
- Surface the behavior clearly in mobile UX and diagnostics

## Non-Goals

- Adding a new Android runtime mode or host adapter
- Claiming stealth or reduced Android detection surface
- Supporting arbitrary operator-entered bypass CIDRs in v1
- Reconfiguring the live VPN session in place without restart

## Decisions

### Decision: Use a separate underlay-route policy axis

The control-plane request for Android platform tunnel startup should keep:

- application routing policy: which apps are captured
- underlay route policy: whether the active local network remains outside the tunnel

These are different concerns and should not share one overloaded enum.

### Decision: Advertise support explicitly through the host contract

Hosts should advertise the supported underlay-route policies for each platform
tunnel mode.
Shells should only render the development Wi-Fi option when the connected host
explicitly supports it.
Older hosts must not silently accept the request and then downgrade to the
standard profile.

### Decision: Preserve only the active local underlay network in v1

The first profile should preserve the currently active local network path rather
than exposing arbitrary CIDR editing.
This keeps the behavior focused on the debugging problem and lets the host
derive the actual exclusion set from the active network state at startup.

Suggested contract names:

- field: `underlay_route_policy`
- default policy: `standard`
- development policy: `preserve_active_local_network`

The UI may label the latter as `Development Wi-Fi`.

### Decision: Compute the exclusion set in the Android host

The Android host owns route preparation and should compute or apply the local
network exclusions there.
On newer Android releases it should prefer `VpnService.Builder.excludeRoute()`.
Where that API is unavailable, it may keep a deterministic route-subtraction
fallback.

The host should also pin the active underlying network when the platform allows
it so the intended Wi-Fi path stays associated with the tunnel bring-up.

### Decision: Keep the profile fail-closed and restart-based

If the host cannot determine the active underlay network, cannot apply the
requested exclusion policy, or detects that the requested policy is unsupported,
startup must fail at route validation or host bring-up.

Changing the underlay-route policy should require stopping and restarting the
platform tunnel.
The first version should not attempt live mutation of the active `VpnService`
session.

### Decision: Surface effective bypass state in diagnostics

The shell and host diagnostics should expose:

- the selected underlay-route policy
- whether the host actually applied it
- the effective active underlay network snapshot or exclusion routes
- the fail-closed error when that profile could not be prepared

## Risks / Trade-offs

- Preserving local-network reachability intentionally weakens pure full-tunnel
  semantics on the active LAN, so the UX must describe that trade-off clearly.
- Active-network snapshotting can become stale if the device roams to a
  different Wi-Fi network while the VPN is already active; v1 should require a
  restart instead of silently pretending the old snapshot is still correct.
- IPv4-only heuristics are not enough long-term; the host implementation must
  either stay explicit about IPv4-only limits or add IPv6-aware handling before
  claiming complete support.
- The control-plane contract becomes slightly wider, but that is preferable to
  hiding routing behavior behind Android-only heuristics.

## Validation Plan

- `openspec validate add-33-android-dev-wifi-routing-profile --strict --no-interactive`
- relevant `go test` for `pkg/clientcontrol`, `internal/androidembeddedhost`,
  and `internal/androidplatformbridge`
- relevant Flutter/controller/widget tests for `mobile/gui_shell` and
  `packages/flutter_shell_core`
- physical-device validation that Wi-Fi-connected development tooling remains
  reachable after enabling the packaged Android VPN with the development Wi-Fi
  profile
