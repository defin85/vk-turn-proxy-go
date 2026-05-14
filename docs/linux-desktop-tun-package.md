# Linux Desktop TUN Package Runbook

This runbook defines the repo-owned Linux `linux_tun` support surface.
The promoted target is Ubuntu desktop only. A raw `go run`, a hand-copied
`clientd`, or an unpackaged Flutter bundle is not a supported Linux TUN host.

## Build

From the repository root on a Linux host with the pinned Flutter desktop
toolchain:

```bash
make build-gui-linux
```

The build stages the package under `dist/linux-gui/` and writes build metadata
to:

- `dist/build/linux-gui-build-metadata.json`
- `dist/linux-gui/build-metadata.json`

The staged package must include:

- `relaydock`: the Flutter Linux desktop executable
- `clientd`: the sibling sidecar launcher discovered by the GUI
- `libexec/clientd`: the real Go control-plane host
- `libexec/relaydock-linux-tun-helper`: the narrow privileged Linux TUN helper
- `share/applications/com.defin85.relaydock.desktop`: the system desktop entry
  that maps the packaged app id to `/opt/relaydock/relaydock`
- `share/icons/hicolor/256x256/apps/com.defin85.relaydock.png`: the desktop
  environment icon-theme asset used by launchers and docks
- `share/polkit-1/actions/com.defin85.relaydock.linux-tun.policy`: the polkit
  action tied only to `/opt/relaydock/libexec/relaydock-linux-tun-helper`
- `install-ubuntu.sh`: the Ubuntu install entrypoint

The package must not stage `libexec/relaydock-clientd-linux-tun`, a root
`clientd` wrapper, a `sudo -A` askpass helper, or a root-owned live
transport-profile store.

## Install

On the supported Ubuntu target:

```bash
sudo dist/linux-gui/install-ubuntu.sh
```

Build an installable `.deb` from the staged package:

```bash
make package-gui-linux-deb
```

The Debian artifact is written under `dist/linux-deb/` with a `.sha256`
checksum. It installs the same `/opt/relaydock` payload, desktop entry, icon,
helper-only polkit action, and unprivileged launcher as the scripted installer.

The installer places the package under `/opt/relaydock`, installs the desktop
entry under `/usr/share/applications/`, installs the launcher icon under
`/usr/share/icons/hicolor/`, and installs the polkit action under
`/usr/share/polkit-1/actions/`.

Launch the GUI from the installed package:

```bash
/opt/relaydock/relaydock
```

The GUI discovers the sibling `/opt/relaydock/clientd` launcher. That launcher
runs `/opt/relaydock/libexec/clientd` as the operator user with
`VKTP_LINUX_PACKAGED_TARGET=ubuntu`. Ordinary local-host startup must not ask
for a password and must not cross into root. `/v1/host`, provider sources,
profile repair, diagnostics, and browser-assisted provider continuation all
belong to that unprivileged host.

## Privilege Boundary

Linux privilege is acquired only when the operator starts the `linux_tun`
platform tunnel. The host may invoke:

```bash
pkexec /opt/relaydock/libexec/relaydock-linux-tun-helper start
```

The helper is package-internal. It reads one strict JSON payload from stdin and
writes one strict JSON response to stdout. It does not listen on HTTP, a socket,
or any GUI-facing API.

The helper payload is attempt scoped and may include only:

- protocol/schema version and helper identity
- startup attempt id and attempt nonce
- selected `linux_tun` execution plan identity
- materialized WireGuard-over-TURN execution lease
- host-owned route/DNS policy directives for that attempt

It must not receive provider identifiers, provider links, browser settings,
profile-store paths, shell persistence paths, arbitrary file paths, or unknown
schema fields. Helper diagnostics must redact attempt nonces, TURN credentials,
WireGuard private material, preshared keys, and transport-profile store paths.

If the operator denies or cannot complete the polkit prompt, the host reports a
typed platform-tunnel failure at `permission_acquire` with missing prerequisite
`permission`. The local host remains reachable; the GUI must not translate this
into `Local host blocked`.

## Profile Store

Packaged Linux profile persistence is owned by the operator user's host. The
default store path is:

```text
${XDG_CONFIG_HOME:-$HOME/.config}/vk-turn-proxy-go/vpn-transport-profiles/store.json
```

When `$XDG_CONFIG_HOME` is unavailable, the fallback is:

```text
$HOME/.vk-turn-proxy-go/vpn-transport-profiles/store.json
```

The legacy root-owned package path:

```text
/var/lib/relaydock/vpn-transport-profiles/store.json
```

is not a live second store. If it exists, treat it as legacy state that must be
handled through a reviewed one-time migration/import path or explicit
setup-needed diagnostics. Do not point the normal package launcher or helper at
that path.

## Browser Continuation

Browser-assisted provider continuation starts from unprivileged `clientd`, not
from the helper and not from root. The controlled browser must inherit the
operator user's desktop session naturally through the user-space host process.
There is no normal-path `DISPLAY`/`XAUTHORITY`/browser env bridge into a root
`clientd`.

Non-snap Chrome or Chromium remains the preferred smoke-test browser because it
avoids snap confinement surprises, but the package no longer depends on
cross-user browser startup.

## Support Gate

Before claiming Linux `linux_tun` as shipped on an Ubuntu target, capture all of
these facts from the installed package:

1. `make build-gui-linux` succeeds and `dist/linux-gui/` contains the GUI,
   sidecar launcher, real host, privileged helper, polkit policy, installer,
   and build metadata.
2. `make package-gui-linux-deb` succeeds and the `.deb` contains separate
   `libexec/clientd` and `libexec/relaydock-linux-tun-helper` artifacts. It must
   not contain `libexec/relaydock-clientd-linux-tun`.
3. The polkit policy authorizes only
   `/opt/relaydock/libexec/relaydock-linux-tun-helper`, not
   `/opt/relaydock/clientd` or `/opt/relaydock/libexec/clientd`.
4. The Debian dependency set does not add `sudo` or `zenity`; ordinary host
   startup does not use an askpass path.
5. An unpackaged host fails closed. For example, `go run ./cmd/clientd` must not
   report `linux_tun available=true`; it should name the missing packaged
   Ubuntu install surface.
6. The installed GUI starts `/opt/relaydock/clientd` as the operator user and
   `/v1/host` is reachable before any privilege prompt.
7. Browser-assisted provider continuation launches as the operator user, not as
   root, and does not depend on an operator-patched env bridge.
8. Starting `linux_tun` is the first operation that invokes the privileged
   helper. Privilege denial returns `permission_acquire`/`permission` while
   keeping `/v1/host` reachable.
9. Legacy root-owned transport-profile state is migrated once or reported as
   setup-needed; it is not used as a live second store.
10. Startup reaches `ready=true` only after a resolved TURN handoff, compatible
    WireGuard VPN transport profile, helper privilege acquisition, route/DNS
    underlay preservation, strict WireGuard TURN attach, and dataplane evidence.
11. `openspec validate refactor-linux-tun-privilege-helper --strict
    --no-interactive` passes after task/docs/code alignment.

All other Linux targets remain unsupported until they have their own documented
package/install path and verification evidence.
