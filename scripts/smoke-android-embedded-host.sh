#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
LIB_PATH="${TMP_DIR}/libvk_turn_mobile_host.so"
HEADER_PATH="${TMP_DIR}/libvk_turn_mobile_host.h"

cleanup() {
  python3 - "${TMP_DIR}" <<'PY'
import pathlib
import shutil
import sys

shutil.rmtree(pathlib.Path(sys.argv[1]), ignore_errors=True)
PY
}

trap cleanup EXIT

cd "${ROOT_DIR}"
go build -trimpath -buildmode=c-shared -o "${LIB_PATH}" ./cmd/android-mobile-host

if [[ ! -f "${LIB_PATH}" ]]; then
  echo "embedded host smoke build did not produce ${LIB_PATH}" >&2
  exit 1
fi

if [[ ! -f "${HEADER_PATH}" ]]; then
  echo "embedded host smoke build did not produce ${HEADER_PATH}" >&2
  exit 1
fi

export LIB_PATH
python3 - <<'PY'
import ctypes
import json
import os
import urllib.request

required_capabilities = {
    "mobile_host_bridge",
    "profiles",
    "sessions",
    "challenges",
    "diagnostics",
    "event_stream",
    "vpn-transport-profile-store",
}

lib = ctypes.CDLL(os.environ["LIB_PATH"])
lib.AndroidEmbeddedHostEnsureStarted.restype = ctypes.c_void_p
lib.AndroidEmbeddedHostLastError.restype = ctypes.c_void_p
lib.AndroidEmbeddedHostStop.restype = None
lib.AndroidEmbeddedHostSetTransportProfileStorePath.argtypes = [ctypes.c_char_p]
lib.AndroidEmbeddedHostSetTransportProfileStorePath.restype = None
lib.AndroidEmbeddedHostFreeString.argtypes = [ctypes.c_void_p]
lib.AndroidEmbeddedHostFreeString.restype = None


def read_c_string(ptr):
    if not ptr:
        return ""
    try:
        return ctypes.cast(ptr, ctypes.c_char_p).value.decode("utf-8")
    finally:
        lib.AndroidEmbeddedHostFreeString(ptr)


store_path = os.path.join(
    os.path.dirname(os.environ["LIB_PATH"]),
    "no-backup",
    "vpn-transport-profiles",
    "store.json",
)
lib.AndroidEmbeddedHostSetTransportProfileStorePath(store_path.encode("utf-8"))
base_ptr = lib.AndroidEmbeddedHostEnsureStarted()
base_url = read_c_string(base_ptr)
if not base_url:
    message = read_c_string(lib.AndroidEmbeddedHostLastError())
    raise SystemExit(message or "embedded host smoke failed to return a base URL")

if not base_url.startswith("http://127.0.0.1:"):
    raise SystemExit(f"unexpected embedded host base URL: {base_url}")

try:
    with urllib.request.urlopen(base_url + "/v1/host", timeout=5) as response:
        host_info = json.load(response)

    request = urllib.request.Request(
        base_url + "/v1/negotiate",
        data=json.dumps(
            {
                "supported_versions": [host_info["contract_version"]],
                "required_capabilities": sorted(required_capabilities),
            }
        ).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(request, timeout=5) as response:
        negotiated = json.load(response)

    platform_tunnels = host_info.get("platform_tunnels", [])
    if not platform_tunnels:
        raise SystemExit("embedded host did not publish a platform_tunnels report")

    mode = platform_tunnels[0].get("mode", "").strip()
    if not mode:
        raise SystemExit("embedded host platform_tunnels report did not include a mode")

    start_request = urllib.request.Request(
        base_url + "/v1/platform-tunnels/start",
        data=json.dumps({"mode": mode}).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(start_request, timeout=5) as response:
        missing_profile_start_result = json.load(response)

    import_request = urllib.request.Request(
        base_url + "/v1/transport-profiles",
        data=json.dumps(
            {
                "adapter": "wireguard_conf",
                "kind": "wireguard_native_v1",
                "display_name": "smoke Android VPN transport profile",
                "material": "\n".join(
                    [
                        "[Interface]",
                        "PrivateKey = smoke-client-private-key",
                        "Address = 10.10.0.2/32",
                        "",
                        "[Peer]",
                        "PublicKey = smoke-peer-public-key",
                        "AllowedIPs = 0.0.0.0/0",
                        "Endpoint = relay.example.test:51820",
                        "",
                    ]
                ),
            }
        ).encode("utf-8"),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(import_request, timeout=5) as response:
        imported_profile = json.load(response)

    with urllib.request.urlopen(base_url + "/v1/transport-profiles", timeout=5) as response:
        transport_profiles = json.load(response)

    with urllib.request.urlopen(start_request, timeout=5) as response:
        permission_start_result = json.load(response)
finally:
    lib.AndroidEmbeddedHostStop()

if host_info.get("contract_version") != "1":
    raise SystemExit(
        f"unexpected host contract_version: {host_info.get('contract_version')}"
    )

missing = required_capabilities - set(negotiated.get("capabilities", []))
if missing:
    raise SystemExit(
        "embedded host negotiation missing capabilities: " + ",".join(sorted(missing))
    )

role = negotiated.get("build", {}).get("role")
if role != "android_embedded_host":
    raise SystemExit(f"unexpected embedded host build role: {role}")

if missing_profile_start_result.get("ready") is not False:
    raise SystemExit(
        f"unexpected missing-profile start readiness: {missing_profile_start_result}"
    )

if missing_profile_start_result.get("stage") != "profile_validate":
    raise SystemExit(
        "unexpected missing-profile start stage: "
        + str(missing_profile_start_result.get("stage"))
    )

if missing_profile_start_result.get("missing_prerequisite") != "transport_profile":
    raise SystemExit(
        "unexpected missing-profile prerequisite: "
        + str(missing_profile_start_result.get("missing_prerequisite"))
    )

if imported_profile.get("kind") != "wireguard_native_v1":
    raise SystemExit(f"unexpected imported profile: {imported_profile}")

profiles_json = json.dumps(transport_profiles)
if "smoke-client-private-key" in profiles_json or store_path in profiles_json:
    raise SystemExit(f"transport profile read leaked secret material/path: {profiles_json}")

if permission_start_result.get("ready") is not False:
    raise SystemExit(
        f"unexpected platform tunnel start readiness: {permission_start_result}"
    )

if permission_start_result.get("stage") != "permission_acquire":
    raise SystemExit(
        "unexpected platform tunnel start stage: "
        + str(permission_start_result.get("stage"))
    )

if permission_start_result.get("missing_prerequisite") != "permission":
    raise SystemExit(
        "unexpected platform tunnel missing_prerequisite: "
        + str(permission_start_result.get("missing_prerequisite"))
    )

print(f"embedded host smoke passed: {base_url}")
PY
