#!/usr/bin/env python3
"""Prove the packaged Android VpnService path can reach ready=true on device."""

from __future__ import annotations

import argparse
import base64
import json
import os
import shutil
import socket
import subprocess
import sys
import time
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
DEFAULT_LISTEN_ADDR = "127.0.0.1:39000"
DEFAULT_PEER_ADDR = "176.109.104.105:56040"
DEFAULT_CLIENT_ADDRESS = "10.10.0.2/32"
DEFAULT_DNS_SERVER = "1.1.1.1"
DEFAULT_ALLOWED_IP = "0.0.0.0/0"
DEFAULT_MTU = 1280
DEFAULT_PEER_PUBLIC_KEY = "AgICAgICAgICAgICAgICAgICAgICAgICAgICAgICAgI="
DEFAULT_TRANSPORT_PROFILE_NAME = "smoke Android VPN transport profile"
DEFAULT_STRUCTURED_WIREGUARD_SCHEMA = "wireguard_native_v1.structured_editor.v1"
STRICT_ANDROID_VPN_PLAN = {
    "access_method": "turn_credentials",
    "carrier_family": "turn_datagram",
    "engine_family": "wireguard_native",
    "host_adapter": "android_vpn_service",
}


class ToolError(RuntimeError):
    pass


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if check and proc.returncode != 0:
        raise ToolError(
            f"{' '.join(cmd)} failed with exit code {proc.returncode}: "
            f"{(proc.stderr or proc.stdout).strip()}"
        )
    return proc


def ps_single_quote(value: str) -> str:
    return value.replace("'", "''")


def powershell(script: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    encoded = base64.b64encode(script.encode("utf-16le")).decode("ascii")
    return run(
        ["powershell.exe", "-NoProfile", "-EncodedCommand", encoded],
        check=check,
    )


def request_json(url: str, method: str = "GET", payload: dict[str, Any] | None = None, timeout: int = 10) -> Any:
    body_prelude = ""
    body_arg = ""
    content_type_arg = ""
    if payload is not None:
        body_prelude = "$body = @'\n" + json.dumps(payload, indent=2) + "\n'@\n"
        body_arg = " -Body $body"
        content_type_arg = " -ContentType 'application/json'"
    script = f"""
$ProgressPreference = 'SilentlyContinue'
{body_prelude}try {{
  $response = Invoke-WebRequest -UseBasicParsing -Uri '{ps_single_quote(url)}' -Method {method}{content_type_arg}{body_arg} -TimeoutSec {timeout}
  [Console]::Out.Write($response.Content)
}} catch {{
  if ($_.Exception.Response -ne $null) {{
    $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
    $responseBody = $reader.ReadToEnd()
    [Console]::Error.Write("HTTP " + [int]$_.Exception.Response.StatusCode + ": " + $responseBody)
    exit 1
  }}
  [Console]::Error.Write($_.Exception.ToString())
  exit 1
}}
"""
    proc = powershell(script)
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError as exc:
        raise ToolError(f"failed to decode JSON from {method} {url}: {proc.stdout!r}") from exc


def concise_tool_error(error: BaseException) -> str:
    message = str(error).strip()
    marker = " failed with exit code "
    if marker in message:
        message = message.split(marker, 1)[1]
        if ": " in message:
            message = message.split(": ", 1)[1]
    return message[:800]


def detect_single_device(adb: str, serial: str | None) -> str:
    proc = run([adb, "devices", "-l"])
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
        raise ToolError("multiple adb devices are connected; pass --serial")
    return devices[0]


def adb_cmd(adb: str, serial: str, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return run([adb, "-s", serial, *args], check=check)


def adb_shell(adb: str, serial: str, command: str, check: bool = True) -> str:
    return adb_cmd(adb, serial, "shell", command, check=check).stdout


def package_uid(adb: str, serial: str, package: str) -> int:
    output = adb_shell(
        adb,
        serial,
        f"cmd package list packages -U | grep '^package:{package} '",
        check=False,
    )
    for part in output.split():
        if part.startswith("uid:"):
            return int(part.removeprefix("uid:"))
    raise ToolError(f"failed to determine uid for package {package!r}")


def ensure_app_running(adb: str, serial: str, package: str) -> int:
    pid = adb_shell(adb, serial, f"pidof -s {package}", check=False).strip()
    if not pid:
        adb_shell(
            adb,
            serial,
            f"monkey -p {package} -c android.intent.category.LAUNCHER 1 >/dev/null 2>&1",
            check=False,
        )
        time.sleep(2.0)
        pid = adb_shell(adb, serial, f"pidof -s {package}", check=False).strip()
    if not pid:
        raise ToolError(f"package {package!r} is not running")
    return int(pid)


def parse_loopback_listeners(tcp_table: str) -> list[int]:
    ports: list[int] = []
    for line in tcp_table.splitlines()[1:]:
        columns = line.split()
        if len(columns) < 4:
            continue
        local_address = columns[1]
        state = columns[3]
        parts = local_address.split(":")
        if len(parts) != 2:
            continue
        host_hex, port_hex = parts
        if state != "0A" or host_hex != "0100007F":
            continue
        ports.append(int(port_hex, 16))
    return sorted(set(ports))


def discover_host_bridge(adb: str, serial: str, package: str) -> tuple[int, dict[str, Any]]:
    adb_cmd(adb, serial, "forward", "--remove-all", check=False)
    pid = ensure_app_running(adb, serial, package)
    tcp_table = adb_shell(adb, serial, f"cat /proc/{pid}/net/tcp")
    candidates = parse_loopback_listeners(tcp_table)
    if not candidates:
        raise ToolError(f"no loopback listeners found for pid {pid}")
    last_error = "no candidates accepted"
    for index, device_port in enumerate(candidates):
        local_port = 39100 + index
        adb_cmd(adb, serial, "forward", f"tcp:{local_port}", f"tcp:{device_port}")
        try:
            host_info = request_json(f"http://127.0.0.1:{local_port}/v1/host")
        except Exception as exc:  # noqa: BLE001
            last_error = f"{device_port}: {exc}"
            continue
        role = str(host_info.get("build", {}).get("role", "")).strip()
        if role != "android_embedded_host":
            last_error = f"{device_port}: unexpected role {role!r}"
            continue
        return local_port, host_info
    raise ToolError(f"failed to discover Android embedded host: {last_error}")


def wait_for_resolution(local_port: int, resolution_id: str, timeout: float) -> dict[str, Any]:
    deadline = time.time() + timeout
    while time.time() < deadline:
        state = request_json(f"http://127.0.0.1:{local_port}/v1/resolutions/{resolution_id}")
        if state.get("state") != "starting":
            return state
        time.sleep(0.5)
    raise ToolError(f"timed out waiting for resolution {resolution_id} to finish")


def find_wireguard_schema_version(host_info: dict[str, Any]) -> str:
    store = host_info.get("transport_profile_store") or {}
    for editable in store.get("editable_kinds") or []:
        if editable.get("kind") == "wireguard_native_v1":
            schema = str(editable.get("schema_version", "")).strip()
            if schema:
                return schema
    return DEFAULT_STRUCTURED_WIREGUARD_SCHEMA


def create_transport_profile(
    local_port: int,
    host_info: dict[str, Any],
    args: argparse.Namespace,
) -> dict[str, Any]:
    endpoint = args.transport_profile_endpoint or args.peer_addr
    payload = {
        "draft": {
            "kind": "wireguard_native_v1",
            "schema_version": find_wireguard_schema_version(host_info),
            "display_name": args.transport_profile_name,
            "interface_private_key_action": "generate_host",
            "interface_addresses": list(args.client_address),
            "dns_servers": list(args.dns_server),
            "mtu": args.mtu,
            "peer_public_key": args.peer_public_key,
            "allowed_ips": list(args.allowed_ip),
            "endpoint": endpoint,
            "persistent_keepalive_seconds": args.persistent_keepalive,
            "default_for": dict(STRICT_ANDROID_VPN_PLAN),
        }
    }
    created = request_json(
        f"http://127.0.0.1:{local_port}/v1/transport-profiles:structured",
        method="POST",
        payload=payload,
    )
    profile = created.get("profile") or {}
    profile_id = str(profile.get("id", "")).strip()
    if not profile_id:
        raise ToolError(f"structured transport profile response did not include profile.id: {created!r}")
    return profile


def build_start_payload(
    args: argparse.Namespace,
    resolution_id: str,
    transport_profile: dict[str, Any],
) -> dict[str, Any]:
    profile_id = str(transport_profile.get("id", "")).strip()
    if not profile_id:
        raise ToolError(f"transport profile does not include an id: {transport_profile!r}")
    payload: dict[str, Any] = {
        "mode": "android_vpn_service",
        "resolution_id": resolution_id,
        "execution_plan": dict(STRICT_ANDROID_VPN_PLAN),
        "transport_profile": {"profile_id": profile_id},
        "runtime_defaults": {
            "listen_addr": args.listen_addr,
            "peer_addr": args.peer_addr,
            "connections": 1,
            "mode": "auto",
            "use_dtls": True,
            "log_level": args.log_level,
        },
        "application_routing_policy": args.policy,
        "underlay_route_policy": args.underlay_route_policy,
    }
    if args.allowed_package:
        payload["allowed_packages"] = list(args.allowed_package)
    if args.disallowed_package:
        payload["disallowed_packages"] = list(args.disallowed_package)
    return payload


def validate_policy(args: argparse.Namespace) -> None:
    if args.policy == "all_apps":
        if args.allowed_package or args.disallowed_package:
            raise ToolError("all_apps must not include allowed/disallowed package lists")
        return
    if args.policy == "allowed_packages" and not args.allowed_package:
        raise ToolError("allowed_packages requires at least one --allowed-package")
    if args.policy == "disallowed_packages" and not args.disallowed_package:
        raise ToolError("disallowed_packages requires at least one --disallowed-package")
    if args.allowed_package and args.disallowed_package:
        raise ToolError("do not mix --allowed-package and --disallowed-package")


def ensure_vpn_visible(adb: str, serial: str, app_uid: int) -> str:
    output = adb_shell(adb, serial, "dumpsys connectivity")
    if "type: VPN[" not in output:
        raise ToolError("android_vpn_service returned ready=true but dumpsys connectivity does not show VPN[]")
    owner_uid = f"OwnerUid: {app_uid}"
    establishing_uid = f"EstablishingAppUid: {app_uid}"
    if owner_uid not in output and establishing_uid not in output:
        raise ToolError(
            "android_vpn_service returned ready=true but dumpsys connectivity "
            f"does not attribute the VPN to uid {app_uid}"
        )
    return output


def ensure_vpn_not_owned_by_app(adb: str, serial: str, app_uid: int) -> str:
    output = adb_shell(adb, serial, "dumpsys connectivity")
    owner_uid = f"OwnerUid: {app_uid}"
    establishing_uid = f"EstablishingAppUid: {app_uid}"
    if owner_uid in output or establishing_uid in output:
        raise ToolError(f"RelayDock VPN still appears active for uid {app_uid} after stop")
    return output


def stop_platform_tunnel(local_port: int) -> dict[str, Any]:
    stop_result = request_json(
        f"http://127.0.0.1:{local_port}/v1/platform-tunnels/stop",
        method="POST",
        payload={"mode": "android_vpn_service"},
    )
    if stop_result.get("stopped") is not True:
        raise ToolError(
            "android_vpn_service stop did not return stopped=true: "
            + json.dumps(stop_result, sort_keys=True)
        )
    return stop_result


def ready_platform_tunnel_status(local_port: int) -> dict[str, Any]:
    statuses = request_json(f"http://127.0.0.1:{local_port}/v1/platform-tunnels/status")
    if not isinstance(statuses, list):
        raise ToolError(f"platform tunnel status response is not a list: {statuses!r}")
    for status in statuses:
        if status.get("mode") == "android_vpn_service" and status.get("ready") is True:
            return status
    raise ToolError(
        "embedded host did not report a ready android_vpn_service status: "
        + json.dumps(statuses, sort_keys=True)
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default=DEFAULT_ADB)
    parser.add_argument("--serial")
    parser.add_argument("--app-package", default=DEFAULT_APP_PACKAGE)
    parser.add_argument("--turn-link", default=os.environ.get("TURN_LINK", "").strip())
    parser.add_argument("--listen-addr", default=DEFAULT_LISTEN_ADDR)
    parser.add_argument("--peer-addr", default=DEFAULT_PEER_ADDR)
    parser.add_argument("--transport-profile-name", default=DEFAULT_TRANSPORT_PROFILE_NAME)
    parser.add_argument("--transport-profile-endpoint", default="")
    parser.add_argument("--client-address", action="append", default=[DEFAULT_CLIENT_ADDRESS])
    parser.add_argument("--dns-server", action="append", default=[DEFAULT_DNS_SERVER])
    parser.add_argument("--allowed-ip", action="append", default=[DEFAULT_ALLOWED_IP])
    parser.add_argument("--mtu", type=int, default=DEFAULT_MTU)
    parser.add_argument("--peer-public-key", default=DEFAULT_PEER_PUBLIC_KEY)
    parser.add_argument("--persistent-keepalive", type=int, default=0)
    parser.add_argument("--policy", default="all_apps", choices=["all_apps", "allowed_packages", "disallowed_packages"])
    parser.add_argument("--underlay-route-policy", default="preserve_active_local_network", choices=["standard", "preserve_active_local_network"])
    parser.add_argument("--allowed-package", action="append", default=[])
    parser.add_argument("--disallowed-package", action="append", default=[])
    parser.add_argument("--log-level", default="debug")
    parser.add_argument("--resolution-timeout", type=float, default=15.0)
    parser.add_argument("--startup-timeout", type=int, default=90)
    parser.add_argument("--no-cleanup", action="store_true")
    args = parser.parse_args()

    if not args.turn_link:
        raise ToolError("TURN_LINK must be provided via --turn-link or environment")
    validate_policy(args)

    serial = detect_single_device(args.adb, args.serial)
    local_port = 0
    app_uid = package_uid(args.adb, serial, args.app_package)

    try:
        adb_shell(args.adb, serial, f"am force-stop {args.app_package}", check=False)
        adb_shell(args.adb, serial, "logcat -c", check=False)
        ensure_app_running(args.adb, serial, args.app_package)
        local_port, host_info = discover_host_bridge(args.adb, serial, args.app_package)
        transport_profile = create_transport_profile(local_port, host_info, args)

        resolution = request_json(
            f"http://127.0.0.1:{local_port}/v1/resolutions",
            method="POST",
            payload={
                "provider": "generic-turn",
                "input": {"kind": "link", "link": args.turn_link},
            },
        )
        resolution_id = str(resolution.get("id", "")).strip()
        if not resolution_id:
            raise ToolError(f"resolution response did not include an id: {resolution!r}")

        resolved = wait_for_resolution(local_port, resolution_id, args.resolution_timeout)
        if resolved.get("state") != "resolved":
            raise ToolError(f"resolution did not reach resolved state: {json.dumps(resolved, sort_keys=True)}")

        start_request_error = ""
        try:
            start_result = request_json(
                f"http://127.0.0.1:{local_port}/v1/platform-tunnels/start",
                method="POST",
                payload=build_start_payload(args, resolution_id, transport_profile),
                timeout=args.startup_timeout,
            )
        except ToolError as exc:
            start_request_error = concise_tool_error(exc)
            start_result = {}
            time.sleep(2.0)
        if start_result.get("ready") is not True:
            if start_request_error:
                ensure_app_running(args.adb, serial, args.app_package)
                ensure_vpn_visible(args.adb, serial, app_uid)
                local_port, host_info = discover_host_bridge(args.adb, serial, args.app_package)
                ready_status = ready_platform_tunnel_status(local_port)
                start_result = {
                    "mode": "android_vpn_service",
                    "ready": True,
                    "session_id": ready_status.get("session_id", ""),
                    "message": "start request closed before the JSON response; ready state verified via embedded host status and Android connectivity",
                    "request_error": start_request_error,
                }
            else:
                raise ToolError(
                    "android_vpn_service did not reach ready=true: "
                    + json.dumps(start_result, sort_keys=True)
                )

        time.sleep(2.0)
        ensure_app_running(args.adb, serial, args.app_package)
        ensure_vpn_visible(args.adb, serial, app_uid)
        local_port, host_info = discover_host_bridge(args.adb, serial, args.app_package)
        ready_status = ready_platform_tunnel_status(local_port)
        try:
            stop_result = stop_platform_tunnel(local_port)
        except ToolError as exc:
            stop_result = {
                "mode": "android_vpn_service",
                "stopped": True,
                "message": "stop request closed before the JSON response; Android connectivity verification follows",
                "request_error": concise_tool_error(exc),
            }
        time.sleep(1.0)
        ensure_vpn_not_owned_by_app(args.adb, serial, app_uid)

        print(
            json.dumps(
                {
                    "device_serial": serial,
                    "host_port": local_port,
                    "transport_profile_id": transport_profile.get("id"),
                    "resolution_id": resolution_id,
                    "policy": args.policy,
                    "result": start_result,
                    "ready_status": ready_status,
                    "stop_result": stop_result,
                    "host_build": host_info.get("build", {}),
                },
                indent=2,
                sort_keys=True,
            )
        )
        return 0
    finally:
        if local_port:
            adb_cmd(args.adb, serial, "forward", "--remove", f"tcp:{local_port}", check=False)
        if not args.no_cleanup:
            adb_shell(args.adb, serial, f"am force-stop {args.app_package}", check=False)


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ToolError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1)
