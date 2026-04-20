#!/usr/bin/env python3
"""Control the packaged Android embedded host over adb for WG-over-transport PoC."""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any



def default_adb_path() -> str:
    explicit = os.environ.get("ADB", "").strip()
    if explicit:
        return explicit
    path_adb = shutil.which("adb")
    if path_adb:
        return path_adb
    linux_sdk_adb = os.path.expanduser("~/.local/share/android-sdk/platform-tools/adb")
    if os.path.exists(linux_sdk_adb):
        return linux_sdk_adb
    return "/mnt/c/Users/Egor/AppData/Local/Android/Sdk/platform-tools/adb.exe"


DEFAULT_ADB = default_adb_path()
DEFAULT_APP_PACKAGE = "com.defin85.relaydock"
DEFAULT_WIREGUARD_PACKAGE = "com.wireguard.android"
DEFAULT_LISTEN_ADDR = "127.0.0.1:39000"
DEFAULT_PEER_ADDR = "176.109.104.105:56040"
ACTIVE_SESSION_STATES = {"starting", "challenge_required", "ready", "retrying"}


class ToolError(RuntimeError):
    pass


@dataclass
class CommandResult:
    stdout: str
    stderr: str
    returncode: int


@dataclass
class VPNStatus:
    active: bool
    session_id: str | None
    owner_uid: int | None
    app_uid_excluded: bool | None
    uids_spec: str | None


class Adb:
    def __init__(self, adb_path: str, serial: str | None) -> None:
        self.adb_path = adb_path
        self.serial = serial

    def _cmd(self, *args: str) -> list[str]:
        cmd = [self.adb_path]
        if self.serial:
            cmd.extend(["-s", self.serial])
        cmd.extend(args)
        return cmd

    def run(self, *args: str, check: bool = True) -> CommandResult:
        proc = subprocess.run(
            self._cmd(*args),
            text=True,
            capture_output=True,
        )
        result = CommandResult(
            stdout=proc.stdout,
            stderr=proc.stderr,
            returncode=proc.returncode,
        )
        if check and proc.returncode != 0:
            raise ToolError(
                f"adb {' '.join(args)} failed with exit code {proc.returncode}: "
                f"{(proc.stderr or proc.stdout).strip()}"
            )
        return result

    def shell(self, command: str, check: bool = True) -> CommandResult:
        return self.run("shell", command, check=check)


@dataclass
class HostBridge:
    adb: Adb
    device_port: int
    local_port: int
    host_info: dict[str, Any]

    def url(self, path: str) -> str:
        return f"http://127.0.0.1:{self.local_port}{path}"

    def request_json(
        self,
        method: str,
        path: str,
        payload: dict[str, Any] | None = None,
        expected_status: int | tuple[int, ...] = 200,
    ) -> dict[str, Any] | list[Any]:
        statuses = (
            expected_status
            if isinstance(expected_status, tuple)
            else (expected_status,)
        )
        data = None
        headers: dict[str, str] = {}
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        req = urllib.request.Request(
            self.url(path),
            data=data,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(req, timeout=5) as response:
                body = response.read().decode("utf-8")
                if response.status not in statuses:
                    raise ToolError(
                        f"{method} {path} returned unexpected status {response.status}: {body}"
                    )
                return json.loads(body)
        except urllib.error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise ToolError(f"{method} {path} failed with HTTP {exc.code}: {body}") from exc
        except urllib.error.URLError as exc:
            raise ToolError(f"{method} {path} failed: {exc}") from exc

    def close(self) -> None:
        self.adb.run("forward", "--remove", f"tcp:{self.local_port}", check=False)


def print_json(data: Any) -> None:
    json.dump(data, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")


def detect_single_device(adb_path: str, serial: str | None) -> str | None:
    proc = subprocess.run(
        [adb_path, "devices", "-l"],
        text=True,
        capture_output=True,
    )
    if proc.returncode != 0:
        raise ToolError(
            f"adb devices -l failed with exit code {proc.returncode}: {proc.stderr.strip()}"
        )
    devices: list[str] = []
    for line in proc.stdout.splitlines():
        line = line.strip()
        if not line or line.startswith("List of devices"):
            continue
        if "\tdevice" in line or " device " in line:
            devices.append(line.split()[0])
    if serial:
        if serial not in devices:
            raise ToolError(f"adb device {serial!r} is not connected")
        return serial
    if not devices:
        raise ToolError("no adb devices are connected")
    if len(devices) > 1:
        raise ToolError(
            "multiple adb devices are connected; set ANDROID_SERIAL or pass --serial"
        )
    return devices[0]


def free_local_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return int(sock.getsockname()[1])


def ensure_package_installed(adb: Adb, package: str) -> str:
    result = adb.shell(f"pm path {package}", check=False)
    path = result.stdout.strip()
    if result.returncode != 0 or not path.startswith("package:"):
        raise ToolError(f"package {package!r} is not installed on the device")
    return path.removeprefix("package:")


def app_uid(adb: Adb, package: str) -> int:
    result = adb.shell(f"cmd package list packages -U | grep '^package:{package} '", check=False)
    match = re.search(r"uid:(\d+)", result.stdout)
    if not match:
        raise ToolError(f"failed to determine uid for package {package!r}")
    return int(match.group(1))


def app_pid(adb: Adb, package: str) -> int | None:
    result = adb.shell(f"pidof -s {package}", check=False)
    text = result.stdout.strip()
    if not text:
        return None
    try:
        return int(text)
    except ValueError as exc:
        raise ToolError(f"unexpected pidof output for {package!r}: {text!r}") from exc


def ensure_app_running(adb: Adb, package: str) -> int:
    pid = app_pid(adb, package)
    if pid is not None:
        return pid
    adb.shell(
        f"monkey -p {package} -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1",
        check=False,
    )
    time.sleep(2.0)
    pid = app_pid(adb, package)
    if pid is None:
        raise ToolError(
            f"package {package!r} is not running; open it once on the device and retry"
        )
    return pid


def discover_host_ports(adb: Adb, pid: int) -> list[int]:
    result = adb.shell(f"cat /proc/{pid}/net/tcp")
    ports: list[int] = []
    for line in result.stdout.splitlines()[1:]:
        columns = line.split()
        if len(columns) < 8:
            continue
        local_address = columns[1]
        state = columns[3]
        try:
            host_hex, port_hex = local_address.split(":")
        except ValueError:
            continue
        if state != "0A":
            continue
        if host_hex != "0100007F":
            continue
        ports.append(int(port_hex, 16))
    return sorted(set(ports))


def discover_host_bridge(adb: Adb, package: str) -> HostBridge:
    pid = ensure_app_running(adb, package)
    candidates = discover_host_ports(adb, pid)
    if not candidates:
        raise ToolError(
            f"no loopback listeners were found in /proc/{pid}/net/tcp for {package!r}"
        )
    errors: list[str] = []
    for device_port in candidates:
        local_port = free_local_port()
        adb.run("forward", f"tcp:{local_port}", f"tcp:{device_port}")
        try:
            url = f"http://127.0.0.1:{local_port}/v1/host"
            with urllib.request.urlopen(url, timeout=5) as response:
                host_info = json.loads(response.read().decode("utf-8"))
            role = str(host_info.get("build", {}).get("role", "")).strip()
            if role != "android_embedded_host":
                errors.append(f"{device_port}: unexpected role {role!r}")
                adb.run("forward", "--remove", f"tcp:{local_port}", check=False)
                continue
            return HostBridge(
                adb=adb,
                device_port=device_port,
                local_port=local_port,
                host_info=host_info,
            )
        except Exception as exc:  # noqa: BLE001
            errors.append(f"{device_port}: {exc}")
            adb.run("forward", "--remove", f"tcp:{local_port}", check=False)
    joined = "; ".join(errors) if errors else "no candidate returned /v1/host"
    raise ToolError(f"failed to discover Android embedded host: {joined}")


def session_sort_key(session: dict[str, Any]) -> tuple[str, str]:
    return (
        str(session.get("started_at", "")),
        str(session.get("id", "")),
    )


def active_sessions(sessions: list[dict[str, Any]]) -> list[dict[str, Any]]:
    return [session for session in sessions if session.get("state") in ACTIVE_SESSION_STATES]


def matching_sessions(
    sessions: list[dict[str, Any]],
    listen_addr: str,
    peer_addr: str,
) -> list[dict[str, Any]]:
    matches = []
    for session in active_sessions(sessions):
        profile = session.get("profile", {})
        if profile.get("listen_addr") == listen_addr and profile.get("peer_addr") == peer_addr:
            matches.append(session)
    return sorted(matches, key=session_sort_key, reverse=True)


def resolve_session_id(
    sessions: list[dict[str, Any]],
    requested: str,
) -> str:
    if requested != "latest":
        return requested
    if not sessions:
        raise ToolError("no sessions exist on the embedded host")
    active = active_sessions(sessions)
    pool = active or sessions
    latest = max(pool, key=session_sort_key)
    return str(latest["id"])


def metric_value(metrics: str, name: str, labels: dict[str, str]) -> int | None:
    prefix = f"{name}{{"
    for line in metrics.splitlines():
        if not line.startswith(prefix):
            continue
        label_text, _, value_text = line.partition("} ")
        label_blob = label_text[len(prefix) :]
        parsed: dict[str, str] = {}
        for item in label_blob.split(","):
            key, _, raw_value = item.partition("=")
            parsed[key] = raw_value.strip().strip('"')
        if all(parsed.get(key) == value for key, value in labels.items()):
            try:
                return int(float(value_text.strip()))
            except ValueError:
                return None
    return None


def parse_vpn_status(adb: Adb, mobile_app_uid: int) -> VPNStatus:
    result = adb.shell(
        "dumpsys connectivity | grep 'TransportInfo: <VpnTransportInfo'",
        check=False,
    )
    line = ""
    for candidate in result.stdout.splitlines():
        if "TransportInfo: <VpnTransportInfo" in candidate:
            line = candidate
    if not line:
        return VPNStatus(False, None, None, None, None)
    session_match = re.search(r"sessionId=([^,}]+)", line)
    owner_match = re.search(r"OwnerUid: (\d+)", line)
    uids_match = re.search(r"Uids: <\{([^}]*)\}>", line)
    if not owner_match:
        return VPNStatus(True, session_match.group(1) if session_match else None, None, None, None)
    owner_uid = int(owner_match.group(1))
    uids_spec = uids_match.group(1) if uids_match else None
    excluded = None
    if uids_spec is not None:
        included = uid_matches_ranges(mobile_app_uid, uids_spec)
        excluded = not included
    return VPNStatus(
        active=True,
        session_id=session_match.group(1) if session_match else None,
        owner_uid=owner_uid,
        app_uid_excluded=excluded,
        uids_spec=uids_spec,
    )


def uid_matches_ranges(uid: int, ranges_spec: str) -> bool:
    for item in ranges_spec.split(","):
        part = item.strip()
        if not part:
            continue
        if "-" in part:
            start_text, end_text = part.split("-", 1)
            if int(start_text.strip()) <= uid <= int(end_text.strip()):
                return True
            continue
        if uid == int(part):
            return True
    return False


def print_session_summary(session: dict[str, Any]) -> None:
    profile = session.get("profile", {})
    print(f"id={session.get('id')}")
    print(f"state={session.get('state')}")
    print(f"provider={profile.get('provider')}")
    print(f"listen_addr={profile.get('listen_addr')}")
    print(f"peer_addr={profile.get('peer_addr')}")
    print(f"started_at={session.get('started_at')}")


def command_check(args: argparse.Namespace) -> int:
    serial = detect_single_device(args.adb, args.serial)
    adb = Adb(args.adb, serial)
    app_path = ensure_package_installed(adb, args.app_package)
    wg_path = ensure_package_installed(adb, args.wireguard_package)
    mobile_uid = app_uid(adb, args.app_package)
    bridge = discover_host_bridge(adb, args.app_package)
    try:
        sessions = bridge.request_json("GET", "/v1/sessions")
        if not isinstance(sessions, list):
            raise ToolError("embedded host returned a non-list /v1/sessions payload")
        vpn = parse_vpn_status(adb, mobile_uid)
        print(f"device_serial={serial}")
        print(f"app_package={args.app_package}")
        print(f"app_path={app_path}")
        print(f"app_uid={mobile_uid}")
        print(f"wireguard_package={args.wireguard_package}")
        print(f"wireguard_path={wg_path}")
        print(f"embedded_host_port={bridge.device_port}")
        print(f"embedded_host_role={bridge.host_info.get('build', {}).get('role')}")
        print(f"session_count={len(sessions)}")
        print(f"wireguard_vpn_active={'yes' if vpn.active else 'no'}")
        if vpn.session_id:
            print(f"wireguard_session_id={vpn.session_id}")
        if vpn.app_uid_excluded is not None:
            print(
                "wireguard_excludes_mobile_app="
                + ("yes" if vpn.app_uid_excluded else "no")
            )
    finally:
        bridge.close()
    return 0


def command_status(args: argparse.Namespace) -> int:
    serial = detect_single_device(args.adb, args.serial)
    adb = Adb(args.adb, serial)
    mobile_uid = app_uid(adb, args.app_package)
    bridge = discover_host_bridge(adb, args.app_package)
    try:
        host_info = bridge.request_json("GET", "/v1/host")
        sessions = bridge.request_json("GET", "/v1/sessions")
        if args.json:
            print_json(
                {
                    "device_serial": serial,
                    "embedded_host_port": bridge.device_port,
                    "host_info": host_info,
                    "vpn": parse_vpn_status(adb, mobile_uid).__dict__,
                    "sessions": sessions,
                }
            )
            return 0
        print(f"device_serial={serial}")
        print(f"embedded_host_port={bridge.device_port}")
        vpn = parse_vpn_status(adb, mobile_uid)
        print(f"wireguard_vpn_active={'yes' if vpn.active else 'no'}")
        if vpn.session_id:
            print(f"wireguard_session_id={vpn.session_id}")
        if vpn.app_uid_excluded is not None:
            print(
                "wireguard_excludes_mobile_app="
                + ("yes" if vpn.app_uid_excluded else "no")
            )
        print("")
        for session in sorted(sessions, key=session_sort_key, reverse=True):
            print_session_summary(session)
            print("")
    finally:
        bridge.close()
    return 0


def command_start(args: argparse.Namespace) -> int:
    turn_link = args.turn_link or os.environ.get("TURN_LINK", "").strip()
    if not turn_link:
        raise ToolError("TURN_LINK must be provided via --turn-link or environment")
    serial = detect_single_device(args.adb, args.serial)
    adb = Adb(args.adb, serial)
    bridge = discover_host_bridge(adb, args.app_package)
    try:
        sessions = bridge.request_json("GET", "/v1/sessions")
        conflicts = matching_sessions(sessions, args.listen_addr, args.peer_addr)
        if conflicts and not args.replace_existing:
            ids = ",".join(str(session["id"]) for session in conflicts)
            raise ToolError(
                f"conflicting active sessions already exist for {args.listen_addr} -> "
                f"{args.peer_addr}: {ids}; rerun with --replace-existing"
            )
        if args.replace_existing:
            for session in conflicts:
                bridge.request_json(
                    "POST",
                    f"/v1/sessions/{session['id']}/stop",
                    payload={},
                )
            deadline = time.time() + args.stop_timeout
            while time.time() < deadline:
                current = bridge.request_json("GET", "/v1/sessions")
                if not matching_sessions(current, args.listen_addr, args.peer_addr):
                    break
                time.sleep(0.5)
            else:
                ids = ",".join(str(session["id"]) for session in conflicts)
                raise ToolError(f"timed out waiting for old sessions to stop: {ids}")

        spec = {
            "provider": "generic-turn",
            "link": turn_link,
            "listen_addr": args.listen_addr,
            "peer_addr": args.peer_addr,
            "ingress": "udp",
            "connections": args.connections,
            "mode": "udp",
            "use_dtls": True,
            "interactive_provider": False,
            "log_level": args.log_level,
        }
        session = bridge.request_json(
            "POST",
            "/v1/sessions",
            payload={"spec": spec},
            expected_status=202,
        )
        session_id = str(session["id"])
        deadline = time.time() + args.ready_timeout
        while time.time() < deadline:
            current = bridge.request_json("GET", f"/v1/sessions/{session_id}")
            state = str(current.get("state", ""))
            if state == "ready":
                diagnostics = bridge.request_json(
                    "GET",
                    f"/v1/sessions/{session_id}/diagnostics",
                )
                metrics = str(diagnostics.get("metrics", ""))
                local_to_relay = metric_value(
                    metrics,
                    "vk_turn_proxy_runtime_forwarded_packets_total",
                    {"direction": "local_to_relay", "provider": "generic-turn", "runtime": "client"},
                )
                relay_to_local = metric_value(
                    metrics,
                    "vk_turn_proxy_runtime_forwarded_packets_total",
                    {"direction": "relay_to_local", "provider": "generic-turn", "runtime": "client"},
                )
                print(f"session_id={session_id}")
                print("state=ready")
                print(f"listen_addr={args.listen_addr}")
                print(f"peer_addr={args.peer_addr}")
                if local_to_relay is not None:
                    print(f"local_to_relay_packets={local_to_relay}")
                if relay_to_local is not None:
                    print(f"relay_to_local_packets={relay_to_local}")
                return 0
            if state in {"failed", "stopped"}:
                print_json(current)
                raise ToolError(f"session {session_id} entered terminal state {state!r}")
            time.sleep(0.5)
        raise ToolError(f"timed out waiting for session {session_id} to reach ready")
    finally:
        bridge.close()


def command_stop(args: argparse.Namespace) -> int:
    serial = detect_single_device(args.adb, args.serial)
    adb = Adb(args.adb, serial)
    bridge = discover_host_bridge(adb, args.app_package)
    try:
        sessions = bridge.request_json("GET", "/v1/sessions")
        session_id = resolve_session_id(sessions, args.session_id)
        stopped = bridge.request_json(
            "POST",
            f"/v1/sessions/{session_id}/stop",
            payload={},
        )
        if args.json:
            print_json(stopped)
        else:
            print(f"session_id={session_id}")
            print(f"state={stopped.get('state')}")
        return 0
    finally:
        bridge.close()


def command_diagnostics(args: argparse.Namespace) -> int:
    serial = detect_single_device(args.adb, args.serial)
    adb = Adb(args.adb, serial)
    bridge = discover_host_bridge(adb, args.app_package)
    try:
        sessions = bridge.request_json("GET", "/v1/sessions")
        session_id = resolve_session_id(sessions, args.session_id)
        diagnostics = bridge.request_json(
            "GET",
            f"/v1/sessions/{session_id}/diagnostics",
        )
        if args.json:
            print_json(diagnostics)
            return 0
        print(f"session_id={session_id}")
        print(f"state={diagnostics.get('session', {}).get('state')}")
        metrics = str(diagnostics.get("metrics", ""))
        for direction in ("local_to_relay", "relay_to_local"):
            packets = metric_value(
                metrics,
                "vk_turn_proxy_runtime_forwarded_packets_total",
                {"direction": direction, "provider": "generic-turn", "runtime": "client"},
            )
            if packets is not None:
                print(f"{direction}_packets={packets}")
        print("")
        print_json(diagnostics)
        return 0
    finally:
        bridge.close()


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Control the packaged Android embedded host over adb for the Android "
            "WireGuard-over-transport PoC."
        )
    )
    parser.add_argument(
        "--adb",
        default=DEFAULT_ADB,
        help="path to adb executable; defaults to WSL/Linux adb discovery with Windows adb.exe fallback",
    )
    parser.add_argument("--serial", help="adb device serial; defaults to ANDROID_SERIAL or the single connected device")
    parser.add_argument("--app-package", default=DEFAULT_APP_PACKAGE)
    parser.add_argument("--wireguard-package", default=DEFAULT_WIREGUARD_PACKAGE)

    subparsers = parser.add_subparsers(dest="command", required=True)

    check_parser = subparsers.add_parser("check", help="validate device/app/host prerequisites")
    check_parser.set_defaults(func=command_check)

    status_parser = subparsers.add_parser("status", help="print host and session state")
    status_parser.add_argument("--json", action="store_true", help="emit JSON instead of a text summary")
    status_parser.set_defaults(func=command_status)

    start_parser = subparsers.add_parser("start", help="start a generic-turn session on the phone")
    start_parser.add_argument("--turn-link", help="generic-turn://... link; defaults to TURN_LINK env")
    start_parser.add_argument("--listen-addr", default=DEFAULT_LISTEN_ADDR)
    start_parser.add_argument("--peer-addr", default=DEFAULT_PEER_ADDR)
    start_parser.add_argument("--connections", type=int, default=1)
    start_parser.add_argument("--log-level", default="info")
    start_parser.add_argument("--ready-timeout", type=float, default=30.0)
    start_parser.add_argument("--stop-timeout", type=float, default=10.0)
    start_parser.add_argument("--replace-existing", action="store_true")
    start_parser.set_defaults(func=command_start)

    stop_parser = subparsers.add_parser("stop", help="stop a phone session")
    stop_parser.add_argument(
        "--session-id",
        default="latest",
        help="session id or 'latest' for the newest active session",
    )
    stop_parser.add_argument("--json", action="store_true")
    stop_parser.set_defaults(func=command_stop)

    diagnostics_parser = subparsers.add_parser("diagnostics", help="show diagnostics for a phone session")
    diagnostics_parser.add_argument(
        "--session-id",
        default="latest",
        help="session id or 'latest' for the newest active session",
    )
    diagnostics_parser.add_argument("--json", action="store_true")
    diagnostics_parser.set_defaults(func=command_diagnostics)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if not args.serial:
        args.serial = os.environ.get("ANDROID_SERIAL")
    try:
        return int(args.func(args))
    except ToolError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
