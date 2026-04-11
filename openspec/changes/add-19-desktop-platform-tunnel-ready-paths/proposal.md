# Change: [19] Add desktop platform tunnel ready paths umbrella

## Why
`add-05-platform-tunnel-integrations` defined the typed host contract for platform tunnels, but desktop support still exists only as OS-family responsibilities and fail-closed placeholders.
The repository already names the intended desktop families in `README.md` as `windows_wintun`, `linux_tun`, and `apple_network_extension`, yet there is no umbrella change that says how desktop support is claimed, how those families stay separate, and which ready path lands first.

The repository still lacks one concrete desktop platform tunnel mode that can reach `ready=true`.
Today the validated Windows operator workflow still depends on an external `WireGuard for Windows` client plus manual host-route management for the current TURN underlay.

Desktop needs one umbrella change so the first Windows delivery does not get mistaken for generic "desktop tunnel support", and later Linux or Apple desktop work can reuse the same host-owned contract instead of reopening the ownership boundary from scratch.

## Sequence
- Order: `19`
- Depends on: `add-02-desktop-gui-shell`, `add-05-platform-tunnel-integrations`, `add-09-native-build-workflows`
- Unblocks: first concrete desktop platform tunnel support claim on Windows, later Linux `linux_tun` and Apple desktop ready-path changes under the same desktop contract

## What Changes
- Establish a desktop umbrella contract for platform tunnel ready paths across `windows_wintun`, `linux_tun`, and `apple_network_extension`, while keeping support claims explicit per packaged target and mode.
- Define desktop-family rules for packaged-host ownership, stage-aware startup, fail-closed cleanup, and underlay/control-traffic exclusions so one OS delivery does not silently imply support on another.
- Define `windows_wintun` as the first concrete desktop ready path delivered under that umbrella, including driver acquisition, route validation, host bring-up, runtime attach, and teardown semantics for the supported Windows target.
- Define the Windows-specific route exclusion, DNS bypass, and control-traffic boundaries required so TURN underlay traffic, control-plane access, provider challenges, and required bootstrap flows do not deadlock the first desktop ready path.
- Define how the desktop GUI shell offers only the documented system tunnel workflow for the packaged target and mode explicitly reported by the bundled host, while preserving fail-closed behavior for unsupported or mispackaged builds.
- Add verification expectations for desktop-family support claims plus packaged Windows smoke, failure cases, and typed ready/failure evidence for the first supported desktop platform tunnel mode.

## Impact
- Affected specs: `platform-tunnel-integration`, `desktop-gui-client`, `desktop-sidecar-host`
- Affected code: future desktop host integrations, Windows `clientd` host integration, desktop GUI shell, control-plane startup reporting, Windows packaging and smoke coverage, runtime and operator docs
