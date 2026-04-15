## Context

The repository already has the core ingredients for packaged desktop system
tunnel work:

- a Flutter desktop shell
- a local Go control plane
- explicit desktop planning tuples for `windows_wintun`, `linux_tun`, and
  desktop-side `apple_network_extension`

What is still missing is an explicit ownership split for how those layers work
together once the product moves beyond fail-closed placeholders into real
desktop system-tunnel startup.

Desktop needs that boundary because the native adapter details differ sharply:

- Windows brings driver/service/privilege concerns
- Linux brings `tun`, routes, and service-manager variation
- Apple desktop likely brings app + extension and entitlement concerns

Those differences are real, but they should not force the repository to reopen
who owns the UI, who owns the control plane, and who owns native tunnel
primitives every time a new desktop adapter ships.

## Goals

- Fix one reusable ownership split for packaged desktop platform-tunnel paths
- Keep the desktop Flutter shell as a typed consumer instead of a second tunnel
  orchestrator
- Keep driver, extension, route, DNS, and OS packet-capture primitives inside
  the packaged desktop host boundary
- Keep startup sequencing, execution-plan ownership, strict carrier
  materialization, and typed ready/failure state under the canonical Go control
  plane
- Keep the shared boundary reusable for `windows_wintun`, `linux_tun`, and
  desktop `apple_network_extension` without inventing one fake generic native
  desktop VPN API

## Non-Goals

- Delivering a concrete ready path for every desktop OS in this change
- Replacing `add-18` as the umbrella for concrete Windows-first delivery
- Moving provider logic or carrier materialization into OS-specific helper code
- Inventing a shell-local desktop tunnel protocol beside the local control plane
- Hiding real Windows/Linux/Apple lifecycle differences behind a weak
  lowest-common-denominator desktop abstraction

## Decisions

### Decision: The desktop GUI stays a typed consumer

The Flutter desktop shell renders:

- capability availability
- execution-plan choice
- stage-aware startup state
- follow-up diagnostics and failure information

It must not own:

- driver or extension installation
- OS route or DNS manipulation
- TUN/Wintun/Network Extension primitive lifecycle
- privileged teardown logic

### Decision: The packaged desktop host owns native tunnel primitives

The packaged desktop host/sidecar owns:

- driver or extension acquisition
- OS route and DNS policy application
- packet-capture primitive lifecycle
- OS-specific cleanup of partial startup state

That keeps privileged desktop mechanics inside the native host boundary instead
of pushing them into the Flutter process.

### Decision: The Go control plane remains the canonical orchestrator

The Go host continues to own:

- typed host capability reporting
- `/v1/platform-tunnels/start`
- runtime-execution plan selection
- strict TURN-datagram carrier materialization
- runtime attach sequencing
- typed stage-aware ready/failure output

The native desktop adapter therefore remains a helper boundary, not a parallel
control plane.

### Decision: The shared boundary is reusable, while native adapters remain OS-specific

The same ownership pattern should apply across supported desktop adapters:

- Flutter shell as typed consumer
- packaged desktop host as native adapter owner
- Go control plane as canonical orchestrator

But the native adapter implementation remains OS-specific.
Windows may use `windows_wintun`.
Linux may use `linux_tun`.
Apple desktop may use `apple_network_extension`.
The repository should therefore reuse one ownership model without pretending
those native lifecycles are interchangeable.

### Decision: Cross-boundary startup semantics stay stage-oriented

The shared desktop boundary should be expressed through typed startup concepts
such as:

- capability or privilege acquisition
- route and policy validation
- native tunnel bring-up
- runtime attach
- cleanup

instead of direct Windows-, Linux-, or Apple-specific API objects.
That keeps the shell and control plane reusable while leaving native adapter
details where they belong.

### Decision: Ready state requires native bring-up and Go runtime attach

The repository must not claim a desktop mode as ready merely because a driver,
adapter, or extension exists.

`ready=true` requires:

- native adapter bring-up success
- successful runtime attach under the Go-owned control-plane path

That rule applies to every future packaged desktop mode.

## Risks / Trade-offs

- A reusable boundary adds IPC/bridge design work before any one desktop mode
  is fully implemented
- If the native helper starts owning runtime semantics, desktop behavior can
  drift away from the canonical control-plane contract
- If the shared boundary leaks OS-specific names, later Linux or Apple work
  will require contract surgery instead of only a new native adapter
- If the design over-abstracts too early, the first Windows implementation can
  become harder without actually making Linux or Apple easier

## Validation Plan

- Add the new `desktop-platform-tunnel-host-boundary` spec
- Extend `desktop-sidecar-host`, `desktop-gui-client`,
  `client-control-plane`, and `platform-tunnel-integration` with the explicit
  ownership split
- Keep the shared boundary stage-oriented and reusable for later desktop
  adapters without forcing Windows API names into Flutter or Go contracts
- `openspec validate add-28-desktop-platform-tunnel-host-boundary --strict --no-interactive`
