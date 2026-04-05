## Context

System-wide traffic capture is the most platform-specific part of the universal client.
Desktop and mobile OSes have different primitives:

- Android uses `VpnService`
- iOS and macOS rely on Network Extension family capabilities
- Windows and Linux require different driver or TUN-host approaches

The shared runtime should not absorb all of that platform detail directly.

## Goals

- Define safe platform tunnel integration boundaries for desktop and mobile shells
- Expose tunnel capability detection through the control plane
- Make entitlement, permission, driver, and route-preparation failures explicit
- Keep packet capture and route management outside provider-specific code

## Non-Goals

- Re-implement all platform tunnel APIs inside the Go transport core
- Claim feature parity across all operating systems from day one
- Blur app-shell behavior and privileged tunnel-host behavior into one process

## Decisions

### Decision: Treat platform tunnel support as host capability, not a guaranteed baseline

Each platform must report whether the needed tunnel primitive is available and authorized before the GUI offers device-wide routing.

### Decision: Keep privileged tunnel work in platform hosts

OS-specific tunnel and route-management logic belongs in platform hosts or extensions, not in provider packages or shared UI code.

### Decision: Fail closed on missing permissions, entitlements, drivers, or exclusion rules

The client must not silently start a partial tunnel path when required platform capabilities are missing.

### Decision: Preserve explicit separation between packet capture and relay underlay

Platform tunnel integrations feed traffic into the client runtime, but the existing provider-backed relay underlay remains separately versioned and tested.

## Risks / Trade-offs

- Platform tunnel implementations are the highest-maintenance part of the client
- iOS/macOS entitlements and Windows/Linux driver dependencies create distribution complexity
- Route exclusion mistakes can break challenge flows or lock the app out of required control traffic

## Validation Plan

- Platform capability and permission tests per OS family
- Integration tests that verify fail-closed startup when a required tunnel primitive is missing
- End-to-end tunnel smoke tests for every supported platform mode before documentation claims support
- `openspec validate add-05-platform-tunnel-integrations --strict --no-interactive`
