## Context

The current repository layout already suggests the intended delivery model:

- Flutter owns the operator UI
- the packaged Android app owns the native platform layer
- the embedded Go host owns canonical client-control behavior

What is still missing is an explicit contract for how those layers cooperate
when the product moves from ordinary same-device runtime control to a real
Android `VpnService` path.

That gap matters because Android `VpnService` is not just another transport
listener.
It mixes:

- permission and foreground-service lifecycle
- package allow/deny routing policy
- route and DNS application
- TUN ownership and teardown

Those are Android responsibilities, but they still need to be coordinated by
the same repo-owned control-plane and runtime semantics that the rest of the
product uses.

## Goals

- Fix one authoritative ownership split for the first Android `VpnService` path
- Keep Flutter as a typed consumer instead of a second tunnel orchestrator
- Keep Android OS primitives in Kotlin/Android code instead of leaking them
  into Go or Flutter
- Keep startup, execution-plan selection, and runtime attach in the canonical
  Go host contract
- Require one package-internal bridge between the Go host and Android adapter
  instead of an ad hoc second control surface
- Keep the ownership pattern reusable for a later
  `apple_network_extension` implementation without collapsing Android and iOS
  into one fake native lifecycle

## Non-Goals

- Delivering the full Android ready path by itself
- Choosing the final low-level bridge transport if multiple package-internal
  implementations remain viable
- Moving provider behavior or carrier materialization into Kotlin
- Redefining runtime-execution planning or strict carrier materialization
  semantics that are already fixed by `add-22` and `add-23`
- Replacing the canonical `/v1/platform-tunnels/start` contract with a
  Flutter-only or Android-only tunnel API
- Inventing one generic mobile VPN API that hides the real lifecycle
  differences between Android `VpnService` and future Apple Network Extension
  work

## Decisions

### Decision: Flutter remains a typed consumer

The Flutter shell renders:

- capability availability
- execution-plan choice
- app-scope choice
- stage-aware startup results

It must not own:

- `VpnService.prepare()`
- `VpnService.Builder`
- package allow/deny application
- TUN/device lifecycle

### Decision: Kotlin owns Android OS primitives

The Android-native layer owns:

- permission acquisition
- `VpnService` lifecycle
- `VpnService.Builder`
- Android foreground-service and notification requirements
- package allow/deny policy application
- Android-specific cleanup of partial VPN state

That boundary keeps Android mechanics inside Android code instead of smearing
them across Flutter widgets or Go transport packages.

### Decision: The embedded Go host remains the canonical orchestrator

The embedded Go host continues to own:

- typed host capability reporting
- `/v1/platform-tunnels/start`
- runtime attach sequencing
- typed stage-aware ready/failure output

This change does not reopen or redefine the execution-plan and carrier
semantics already fixed by `add-22` and `add-23`.
Instead, it fixes which layer consumes those existing contracts when packaged
Android system-tunnel startup crosses into native Android code.

The native Android layer is therefore an adapter boundary, not a second
independent control plane.

### Decision: The ownership pattern is reusable, while native adapters stay platform-specific

The repository should reuse the same ownership split for future packaged mobile
system-tunnel work:

- Flutter remains the typed consumer
- the native platform layer owns OS tunnel primitives
- the embedded Go host remains the canonical orchestrator

However, the native adapter itself stays platform-specific.
Android will use `VpnService`.
Future iOS work may use `apple_network_extension`, entitlements, and an app +
extension lifecycle.
`add-26` should therefore preserve a reusable ownership pattern without
pretending the native adapter mechanics are interchangeable or that a future
adapter must share Android's same-process service model.

### Decision: Android `VpnService` startup crosses a package-internal bridge

The Android package must include one package-internal bridge between the Go
host and the Kotlin `VpnService` adapter.

That bridge is responsible for:

- translating typed Go startup intents into Android-native actions
- returning typed stage/failure information to the Go host
- keeping Flutter out of the middle of VPN bring-up

The shared boundary should stay stage-oriented rather than Android-API-oriented.
That means the bridge semantics should be shaped around concepts such as:

- permission or entitlement acquisition
- route and policy validation
- native tunnel bring-up
- runtime attach
- cleanup

instead of requiring shared layers to understand `VpnService` classes
directly.
That keeps the same control-plane/shell role usable for a later
`apple_network_extension` path even though the native implementation details
will differ.

The implementation detail of that bridge may evolve, but the ownership model
must stay the same.
The shell-visible API stays the existing mobile host bridge plus versioned
client-control contract; the package-internal bridge must not become a second
Flutter-visible or Android-only startup protocol.

### Decision: Ready state requires both Android adapter success and Go runtime attach

The repository must not claim Android system-tunnel readiness only because
`VpnService` started or a TUN device exists.

`ready=true` requires:

- Android permission and route policy success
- Android host bring-up success
- successful runtime attach under the Go-owned control-plane path

## Risks / Trade-offs

- A three-layer packaged architecture adds bridge complexity
- Poor boundary design could create deadlocks between Android service lifecycle
  and Go runtime startup
- If the bridge returns weakly typed errors, shells will fall back to generic
  failure UX and lose the point of the contract
- If Kotlin starts owning runtime semantics, desktop/mobile behavior will drift
  away from the canonical host contract
- If shared layers bake in Android API assumptions too early, a future iOS
  rollout will require a contract rewrite instead of only a new native adapter
- Over-abstracting now could hide real platform differences and produce a weak
  lowest-common-denominator tunnel boundary

## Validation Plan

- Add the new `android-vpnservice-host-boundary` spec
- Extend Android embedded-host, mobile GUI, client-control-plane, and
  platform-tunnel specs with the explicit ownership split
- Require that future implementation and smoke evidence prove startup through
  the packaged Go host plus Kotlin adapter boundary, not through shell-local
  heuristics
- Keep the shared boundary phrased in a way that a future
  `apple_network_extension` path can reuse the same ownership model without
  forcing Android-specific API names into Flutter or Go contracts
- `openspec validate add-26-android-vpnservice-host-boundary --strict --no-interactive`
