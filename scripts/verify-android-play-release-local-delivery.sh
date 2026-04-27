#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLETOOL_VERSION="1.18.1"
BUNDLETOOL_JAR_NAME="bundletool-all-${BUNDLETOOL_VERSION}.jar"
BUNDLETOOL_URL="https://github.com/google/bundletool/releases/download/${BUNDLETOOL_VERSION}/${BUNDLETOOL_JAR_NAME}"
BUNDLETOOL_SHA256="675786493983787ffa11550bdb7c0715679a44e1643f3ff980a529e9c822595c"
DEFAULT_AAB_PATH="${ROOT_DIR}/dist/mobile/android-play-release/app-release.aab"
DEFAULT_WORK_DIR="${ROOT_DIR}/dist/build/android-play-release-local-delivery"

usage() {
  cat <<EOF
Usage: $0 [--aab PATH] [--device-id SERIAL | --device-spec PATH] [--work-dir PATH]

Builds device-targeted APK splits from a signed Android App Bundle with the
pinned bundletool-all jar and verifies the local Play-delivery surface.

Defaults:
  --aab       ${DEFAULT_AAB_PATH}
  --work-dir ${DEFAULT_WORK_DIR}

If neither --device-id nor --device-spec is supplied, the script uses a
repo-owned synthetic Android 14 arm64/ru/xxhdpi device spec matching the
published-launch recovery target class.
EOF
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

sha256_file() {
  python3 -c '
import hashlib
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
h = hashlib.sha256()
with path.open("rb") as handle:
    while True:
        chunk = handle.read(1024 * 1024)
        if not chunk:
            break
        h.update(chunk)
print(h.hexdigest())
' "$1"
}

download_bundletool_jar() {
  local jar_path="$1"
  python3 -c '
import pathlib
import sys
import urllib.request

url = sys.argv[1]
path = pathlib.Path(sys.argv[2])
tmp_path = path.with_suffix(path.suffix + ".tmp")
path.parent.mkdir(parents=True, exist_ok=True)
with urllib.request.urlopen(url) as response, tmp_path.open("wb") as handle:
    while True:
        chunk = response.read(1024 * 1024)
        if not chunk:
            break
        handle.write(chunk)
tmp_path.replace(path)
' "${BUNDLETOOL_URL}" "${jar_path}"
}

verify_bundletool_jar() {
  local jar_path="$1"
  local actual_sha
  local actual_version

  actual_sha="$(sha256_file "${jar_path}")"
  if [[ "${actual_sha}" != "${BUNDLETOOL_SHA256}" ]]; then
    echo "bundletool-all SHA-256 mismatch for ${jar_path}: ${actual_sha}" >&2
    echo "expected: ${BUNDLETOOL_SHA256}" >&2
    exit 1
  fi

  actual_version="$(java -jar "${jar_path}" version | tail -n 1 | tr -d '\r')"
  if [[ "${actual_version}" != "${BUNDLETOOL_VERSION}" ]]; then
    echo "bundletool-all version mismatch for ${jar_path}: ${actual_version}" >&2
    echo "expected: ${BUNDLETOOL_VERSION}" >&2
    exit 1
  fi
}

ensure_bundletool_jar() {
  local jar_path="${VKTP_BUNDLETOOL_JAR:-}"
  local cache_root="${ROOT_DIR}/dist/build/vendor/bundletool/${BUNDLETOOL_VERSION}"
  local cached_jar="${cache_root}/${BUNDLETOOL_JAR_NAME}"
  local actual_sha

  if [[ -n "${jar_path}" ]]; then
    if [[ ! -f "${jar_path}" ]]; then
      echo "VKTP_BUNDLETOOL_JAR does not point to a file: ${jar_path}" >&2
      exit 1
    fi
    verify_bundletool_jar "${jar_path}"
    echo "${jar_path}"
    return
  fi

  mkdir -p "${cache_root}"
  if [[ ! -f "${cached_jar}" ]]; then
    echo "downloading ${BUNDLETOOL_JAR_NAME}" >&2
    download_bundletool_jar "${cached_jar}"
  fi

  actual_sha="$(sha256_file "${cached_jar}")"
  if [[ "${actual_sha}" != "${BUNDLETOOL_SHA256}" ]]; then
    echo "cached bundletool-all hash mismatch; refreshing ${cached_jar}" >&2
    download_bundletool_jar "${cached_jar}"
  fi

  verify_bundletool_jar "${cached_jar}"
  echo "${cached_jar}"
}

write_default_device_spec() {
  local output_path="$1"
  python3 -c '
import json
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
payload = {
    "supportedAbis": ["arm64-v8a", "armeabi-v7a", "armeabi"],
    "supportedLocales": ["ru-RU", "ru", "en-US"],
    "screenDensity": 440,
    "sdkVersion": 34,
}
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${output_path}"
}

verify_apks() {
  local apks_path="$1"
  local device_spec_path="$2"
  local report_path="$3"
  python3 -c '
import io
import json
import pathlib
import sys
import zipfile

apks_path = pathlib.Path(sys.argv[1])
device_spec_path = pathlib.Path(sys.argv[2])
report_path = pathlib.Path(sys.argv[3])

spec = json.loads(device_spec_path.read_text(encoding="utf-8"))
supported_abis = [str(item) for item in spec.get("supportedAbis", []) if str(item).strip()]
if not supported_abis:
    raise SystemExit(f"device spec missing supportedAbis: {device_spec_path}")

required_native_libs = [
    "libflutter.so",
    "libandroid_mobile_host_jni.so",
    "libvk_turn_mobile_host.so",
]
required_bridge_methods = [
    "isAndroidVpnPermissionGranted",
    "validateAndroidVpnRoutePolicy",
    "bringupAndroidVpnHost",
    "protectAndroidVpnSocket",
    "duplicateAndroidVpnTunFd",
    "cleanupAndroidVpnHost",
]
forbidden_assets = [
    "assets/wireguard/phone1.conf",
    "assets/adi-registration.properties",
]

apk_members = []
dex_payloads = []
native_hits = {abi: set() for abi in supported_abis}
forbidden_hits = []

with zipfile.ZipFile(apks_path) as apks:
    apk_members = sorted(name for name in apks.namelist() if name.endswith(".apk"))
    if not apk_members:
        raise SystemExit(f"bundletool output does not contain APK splits: {apks_path}")

    for apk_member in apk_members:
        with zipfile.ZipFile(io.BytesIO(apks.read(apk_member))) as apk:
            names = set(apk.namelist())

            for forbidden in forbidden_assets:
                if forbidden in names:
                    forbidden_hits.append(f"{apk_member}!{forbidden}")

            for abi in supported_abis:
                for lib_name in required_native_libs:
                    entry = f"lib/{abi}/{lib_name}"
                    if entry in names:
                        native_hits[abi].add(lib_name)

            for name in sorted(names):
                if name == "classes.dex" or (name.startswith("classes") and name.endswith(".dex")):
                    dex_payloads.append((f"{apk_member}!{name}", apk.read(name)))

if forbidden_hits:
    raise SystemExit(
        "local Play-delivery APKs contain forbidden release assets:\n"
        + "\n".join(f"  - {hit}" for hit in forbidden_hits)
    )

selected_abi = None
for abi in supported_abis:
    if all(lib_name in native_hits[abi] for lib_name in required_native_libs):
        selected_abi = abi
        break
if selected_abi is None:
    def format_native_hits(abi):
        observed = ",".join(sorted(native_hits[abi])) or "none"
        return f"{abi}=[{observed}]"

    details = ", ".join(
        format_native_hits(abi)
        for abi in supported_abis
    )
    raise SystemExit(
        "local Play-delivery APKs do not contain the required native host "
        f"libraries for any supported ABI. Observed: {details}"
    )

if not dex_payloads:
    raise SystemExit("local Play-delivery APKs do not contain classes*.dex")

combined_dex = b"".join(payload for _, payload in dex_payloads)
missing_methods = [
    method for method in required_bridge_methods
    if method.encode("ascii") not in combined_dex
]
if missing_methods:
    raise SystemExit(
        "local Play-delivery APKs are missing JNI bridge callback method names "
        "from delivered dex. Release shrink/obfuscation likely removed methods "
        "required by vktp_register_platform_tunnel_bridge:\n"
        + "\n".join(f"  - {method}" for method in missing_methods)
    )

report = {
    "apks": str(apks_path),
    "device_spec": str(device_spec_path),
    "apk_splits": apk_members,
    "selected_abi": selected_abi,
    "required_native_libs": required_native_libs,
    "required_bridge_methods": required_bridge_methods,
    "forbidden_assets": forbidden_assets,
    "dex_files": [name for name, _ in dex_payloads],
}
report_path.parent.mkdir(parents=True, exist_ok=True)
report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")

print("Verified Android Play local delivery:")
print(f"- APK set: {apks_path}")
print(f"- device spec: {device_spec_path}")
print("- APK splits: " + ", ".join(apk_members))
print(f"- native ABI: {selected_abi}")
print("- dex bridge methods: " + ", ".join(required_bridge_methods))
print(f"- report: {report_path}")
' "${apks_path}" "${device_spec_path}" "${report_path}"
}

AAB_PATH="${DEFAULT_AAB_PATH}"
WORK_DIR="${DEFAULT_WORK_DIR}"
DEVICE_ID=""
DEVICE_SPEC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --aab)
      shift
      AAB_PATH="${1:-}"
      ;;
    --device-id)
      shift
      DEVICE_ID="${1:-}"
      ;;
    --device-spec)
      shift
      DEVICE_SPEC="${1:-}"
      ;;
    --work-dir)
      shift
      WORK_DIR="${1:-}"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [[ -n "${DEVICE_ID}" && -n "${DEVICE_SPEC}" ]]; then
  echo "use either --device-id or --device-spec, not both" >&2
  exit 1
fi
if [[ -z "${AAB_PATH}" || ! -f "${AAB_PATH}" ]]; then
  echo "Android App Bundle not found: ${AAB_PATH}" >&2
  exit 1
fi

require_command python3
require_command java

mkdir -p "${WORK_DIR}"
BUNDLETOOL_JAR="$(ensure_bundletool_jar)"
DEVICE_SPEC_PATH="${DEVICE_SPEC}"
if [[ -n "${DEVICE_ID}" ]]; then
  DEVICE_SPEC_PATH="${WORK_DIR}/device-spec-${DEVICE_ID}.json"
  java -jar "${BUNDLETOOL_JAR}" get-device-spec \
    --device-id "${DEVICE_ID}" \
    --output "${DEVICE_SPEC_PATH}"
elif [[ -n "${DEVICE_SPEC_PATH}" ]]; then
  if [[ ! -f "${DEVICE_SPEC_PATH}" ]]; then
    echo "device spec not found: ${DEVICE_SPEC_PATH}" >&2
    exit 1
  fi
else
  DEVICE_SPEC_PATH="${WORK_DIR}/device-spec-default-android14-arm64-ru.json"
  write_default_device_spec "${DEVICE_SPEC_PATH}"
fi

APKS_PATH="${WORK_DIR}/app-release.apks"
REPORT_PATH="${WORK_DIR}/verification-report.json"

java -jar "${BUNDLETOOL_JAR}" build-apks \
  --bundle="${AAB_PATH}" \
  --output="${APKS_PATH}" \
  --device-spec="${DEVICE_SPEC_PATH}" \
  --overwrite

verify_apks "${APKS_PATH}" "${DEVICE_SPEC_PATH}" "${REPORT_PATH}"
