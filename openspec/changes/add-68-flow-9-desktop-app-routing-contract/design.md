## Context

Mobile app routing currently works because Android exposes package-scoped VPN
routing primitives through `VpnService`.
Desktop does not have the same primitive in the current repository contract.
The desktop Wintun path can own an adapter and routes, but that alone cannot
answer "route only this application" because destination routes do not identify
the originating process.

## Goals

- Define a desktop app-routing contract before any UI or host implementation
  claims support
- Keep app routing separate from IP, DNS, and underlay-route policy
- Let shells render host-provided desktop application identities
- Require host-side enforcement evidence before advertising support
- Preserve Android package-routing behavior without renaming it into a generic
  desktop concept

## Non-Goals

- Shipping a Windows classifier in this contract-only change
- Promising app routing for Linux or macOS before native feasibility is proven
- Reusing Android package names as desktop app identifiers
- Treating Wintun route readiness as proof of app-routing enforcement
- Live-mutating a running tunnel scope without a documented reconnect path

## Decisions

### Decision: Desktop app routing uses desktop application identities

The shared desktop contract should model selectors over host-reported
application identities.
The portable shape can include stable fields such as platform, display name,
identity kind, executable path, and a host-owned opaque identity key.
Platform-specific enrichments such as Windows AppUserModelId, signing metadata,
bundle identifiers, or service identity can be added by a concrete host without
forcing Android package terminology into desktop.

### Decision: Enforcement is capability-specific

The host may advertise desktop app routing only for a platform-tunnel mode that
has a verified app classifier or enforcement layer.
Support for `windows_wintun`, `linux_tun`, or `apple_network_extension` remains
insufficient by itself.

### Decision: Android package routing stays a separate policy

The existing `application_routing_policy`, `allowed_packages`, and
`disallowed_packages` request fields describe Android package scope.
Desktop app routing should use explicit desktop selector fields rather than
overloading package lists with executable paths.

### Decision: Scope changes are new startup attempts

Changing the set of routed desktop applications after readiness should be
treated as a new startup attempt unless a later change explicitly defines live
mutation.
That keeps route scope and enforcement state auditable and avoids implying that
a running tunnel changed scope when the host did not reconnect or reconfigure.

## Risks / Trade-offs

- A separate contract adds schema work before the first Windows implementation,
  but it prevents desktop from inheriting Android-only package semantics.
- A portable identity model can become too weak if it hides platform-specific
  identity quality. The host should therefore report identity kind and
  confidence rather than presenting every app as equally enforceable.
- If support is advertised before enforcement evidence exists, the UI can
  become misleading. The contract keeps that fail-closed.

## Validation Plan

- Add `desktop-application-routing` spec requirements for identity-based,
  capability-gated app routing.
- Extend `client-control-plane` and `platform-tunnel-integration` deltas with
  explicit negotiation and fail-closed support claims.
- Validate with:
  `openspec validate add-68-flow-9-desktop-app-routing-contract --strict --no-interactive`
