# Linux Desktop TUN Package Runbook

This runbook defines the first repo-owned Linux `linux_tun` support surface.
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
- `libexec/relaydock-clientd-linux-tun`: the privileged wrapper that sets
  `VKTP_LINUX_PACKAGED_TARGET=ubuntu`
- `share/applications/com.defin85.relaydock.desktop`: the system desktop entry
  that maps the packaged app id to `/opt/relaydock/relaydock`
- `share/icons/hicolor/256x256/apps/com.defin85.relaydock.png`: the desktop
  environment icon-theme asset used by launchers and docks
- `share/polkit-1/actions/com.defin85.relaydock.linux-tun.policy`: the polkit
  action tied to `/opt/relaydock/libexec/relaydock-clientd-linux-tun`
- `install-ubuntu.sh`: the Ubuntu install entrypoint

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
polkit action, and `/var/lib/relaydock/vpn-transport-profiles/` state directory
as the scripted installer.

The installer places the package under `/opt/relaydock`, installs the desktop
entry under `/usr/share/applications/`, installs the launcher icon under
`/usr/share/icons/hicolor/`, installs the polkit action under
`/usr/share/polkit-1/actions/`, and creates the host-owned VPN transport-profile
state directory under `/var/lib/relaydock/`.

Launch the GUI from the installed package:

```bash
/opt/relaydock/relaydock
```

The GUI discovers the sibling `/opt/relaydock/clientd` launcher. That launcher
uses `pkexec` to start `/opt/relaydock/libexec/relaydock-clientd-linux-tun`,
which runs the real `clientd` with `VKTP_LINUX_PACKAGED_TARGET=ubuntu`.

## Support Gate

Before claiming Linux `linux_tun` as shipped on an Ubuntu target, capture all of
these facts from the installed package:

1. `make build-gui-linux` succeeds and `dist/linux-gui/` contains the GUI,
   sidecar launcher, real host, privileged wrapper, polkit policy, installer,
   and build metadata.
2. An unpackaged host fails closed. For example, `go run ./cmd/clientd` must not
   report `linux_tun available=true`; it should name the missing packaged
   Ubuntu install surface.
3. The installed host reports `linux_tun available=true` from `/v1/host` only
   when the process is launched through the packaged Ubuntu wrapper and the host
   prerequisites are present: root/elevated execution, `/dev/net/tun`, and
   `iproute2`.
4. The desktop shell offers the `linux_tun` startup action only from that
   host-reported capability, not from OS detection or a raw bundle heuristic.
5. Startup reaches `ready=true` through `/v1/platform-tunnels/start` or the GUI
   with a resolved TURN handoff, a compatible WireGuard VPN transport profile,
   route/DNS underlay preservation, strict WireGuard TURN attach, and dataplane
   evidence.
6. Cleanup removes the host-owned TUN routes/interface and the control plane no
   longer reports the tunnel as ready.
7. `openspec validate add-85-flow-10-linux-tun-packaging-support-promotion
   --strict --no-interactive` passes after task/docs/code alignment.

All other Linux targets remain unsupported until they have their own documented
package/install path and verification evidence.
