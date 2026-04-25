## Context

`add-05-platform-tunnel-integrations` established a typed platform tunnel contract, but every repo-owned desktop host still fails closed for platform tunnel modes.
`README.md` already splits future desktop ownership by OS family:

- Windows hosts own `windows_wintun`
- Linux hosts own `linux_tun`
- Apple hosts/extensions own `apple_network_extension`

What is missing is the umbrella rule for desktop as a family:

- one OS-specific ready path must not silently imply desktop-wide support
- packaged desktop hosts, not the GUI shell, own privileged tunnel mechanics
- future Linux and Apple work should inherit the same startup and verification bar

The current Windows proof path routes traffic through an external `WireGuard for Windows` client and requires operator-managed host routes for the current TURN host.
That proves the transport slice and the underlay-exclusion problem, but it does not prove a repo-owned desktop system tunnel workflow.

This change keeps delivery intentionally asymmetric:

- one desktop umbrella contract
- one concrete Windows ready path
- zero claims yet for Linux or Apple desktop readiness

## Goals

- Define one desktop-family contract for platform tunnel ready paths without collapsing Windows, Linux, and Apple desktop modes into a fake generic desktop abstraction
- Deliver the first real `ready=true` desktop platform tunnel mode through `windows_wintun`
- Reuse the existing typed control-plane capability and startup-result surface instead of inventing a Windows-only tunnel protocol
- Keep driver or extension handling, route preparation, DNS bypass, packet capture, and teardown inside the packaged desktop host boundary for every supported mode
- Preserve fail-closed behavior for missing driver or privilege, invalid route policy, and runtime-attach failures
- Require mode-specific support claims and evidence so Windows readiness does not get misreported as Linux or Apple desktop readiness
- Require repo-owned packaged Windows smoke and failure evidence before the repository claims the first desktop system tunnel support

## Non-Goals

- Delivering concrete `linux_tun`, macOS `apple_network_extension`, or mobile ready paths in this change
- Replacing provider resolution, TURN credential acquisition, or the shared transport runtime with Windows-specific code
- Keeping the external `WireGuard for Windows` workflow as the repo-owned production tunnel path
- Treating one verified Windows path as proof that all desktop targets now support system tunnel mode
- Hiding Windows-specific route or DNS constraints behind a generic desktop abstraction before the first ready path is verified

## Decisions

### Decision: Desktop is an umbrella, but support claims remain OS- and mode-specific

The repository should talk about desktop platform tunnels as a family of host-owned ready paths, not as one generic "desktop tunnel" feature.
A verified ready path on one desktop OS must not silently upgrade support claims on another desktop OS.
This lets the desktop shell, control plane, docs, and packaging talk consistently about the family without overstating what is actually shipped.

### Decision: `windows_wintun` is the first concrete delivery slice under the desktop umbrella

The repository already has a packaged Windows desktop shell, a bundled `clientd.exe`, and a native Windows build workflow.
Using that existing delivery path keeps the first desktop ready mode aligned with the product surface that already exists and directly addresses the current operator pain around external VPN tooling and manual route exclusions.
Windows is therefore the first concrete desktop ready path, not the entire desktop story.

### Decision: The packaged desktop sidecar host owns every supported ready path

The packaged desktop host must own driver or extension acquisition, route preparation, DNS bypass behavior, packet capture, and teardown for any supported desktop mode.
For this change that means the packaged Windows host owns `windows_wintun`, while future Linux and Apple modes inherit the same ownership boundary.
The desktop GUI remains a typed consumer of capability and startup results instead of becoming a second tunnel orchestrator.

### Decision: Desktop control-traffic exclusions are mandatory, host-owned, and mode-specific

Every supported desktop mode must define which TURN underlay, control-plane, provider-challenge, and DNS flows bypass the tunnel path so startup and challenge continuation do not deadlock themselves.
In this change the concrete route policy is specified only for `windows_wintun`.
If those exclusions cannot be applied safely, startup must fail before claiming readiness.
The operator should not be required to maintain a moving set of manual `/32` routes for the repo-owned ready path.

### Decision: Desktop ready state requires host-owned bring-up and runtime-attach proof

The repository must not claim desktop system tunnel support merely because a desktop package exists or one OS target can start a privileged helper.
For the first Windows path, readiness is complete only when the packaged host has finished driver validation, prepared the documented route policy, attached the shared runtime successfully, and can report typed success through the existing startup contract.
Future Linux and Apple paths must satisfy the same proof bar with their own host primitives.

### Decision: The current external `WireGuard for Windows` PoC remains a separate compatibility workflow

The external WireGuard operator flow can remain documented as a compatibility or debugging path until the repo-owned Windows mode is verified.
It must not be conflated with the supported `windows_wintun` ready path once the repository starts claiming desktop platform tunnel support.

### Decision: Future Linux and Apple desktop changes must build on this umbrella, not bypass it

Later `linux_tun` and `apple_network_extension` changes should plug into the same desktop-family rules for capability reporting, GUI gating, startup stages, and verification evidence.
They should add OS-specific host details, not reopen whether the desktop shell or shared runtime owns those responsibilities.

## Risks / Trade-offs

- A broader umbrella can invite scope creep if Linux or Apple details leak into the first Windows delivery before the host boundary is stable
- Windows driver installation and privilege rules can make startup sequencing more fragile than the current loopback-only desktop path
- Route or DNS exclusion mistakes can break TURN underlay access, provider challenge continuation, or ordinary control-plane access
- Wintun lifecycle management may interact badly with Windows firewall, network-profile, or existing third-party VPN software on operator machines
- If the umbrella wording is too weak, docs or UI can still overclaim "desktop support" from one verified Windows path

## Validation Plan

- Host and control-plane tests for desktop-family typed capability reporting and Windows `windows_wintun` stage-aware startup results
- Fail-closed coverage for unsupported desktop targets, missing Windows driver or privilege, invalid route exclusion or DNS policy, and runtime-attach cleanup
- At least one repo-owned packaged Windows smoke that proves `windows_wintun` can return `ready=true` on the documented supported target
- Updated runtime and operator docs that describe the desktop umbrella explicitly, claim only the verified Windows desktop mode, and reserve Linux and Apple ready paths for later changes
- `openspec validate add-18-flow-1-desktop-core-platform-tunnel-ready-paths --strict --no-interactive`
