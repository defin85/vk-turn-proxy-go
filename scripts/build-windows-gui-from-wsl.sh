#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINDOWS_MIRROR_UNIX="/mnt/e/Projects/vk-turn-proxy-go"
VERSION_MANIFEST="${ROOT_DIR}/version.json"
WINTUN_VERSION="0.14.1"
WINTUN_URL="https://www.wintun.net/builds/wintun-${WINTUN_VERSION}.zip"
WINTUN_SHA256="07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51"

log_phase() {
  echo "==> $1"
}

phase_complete() {
  local label="$1"
  local started_at="$2"
  echo "--> ${label} complete ($((SECONDS - started_at))s)"
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

download_wintun_zip() {
  local zip_path="$1"
  python3 -c '
import pathlib
import sys
import urllib.request

url = sys.argv[1]
path = pathlib.Path(sys.argv[2])
path.parent.mkdir(parents=True, exist_ok=True)
with urllib.request.urlopen(url) as response, path.open("wb") as handle:
    while True:
        chunk = response.read(1024 * 1024)
        if not chunk:
            break
        handle.write(chunk)
' "${WINTUN_URL}" "${zip_path}"
}

extract_wintun_dll() {
  local zip_path="$1"
  local dll_path="$2"
  python3 -c '
import pathlib
import sys
import zipfile

zip_path = pathlib.Path(sys.argv[1])
dll_path = pathlib.Path(sys.argv[2])
member = "wintun/bin/amd64/wintun.dll"
with zipfile.ZipFile(zip_path) as archive:
    try:
        payload = archive.read(member)
    except KeyError as exc:
        raise SystemExit(f"expected {member} in {zip_path}") from exc
dll_path.parent.mkdir(parents=True, exist_ok=True)
dll_path.write_bytes(payload)
' "${zip_path}" "${dll_path}"
}

ensure_wintun_dll() {
  local cache_root="${ROOT_DIR}/dist/build/vendor/wintun/${WINTUN_VERSION}"
  local zip_path="${cache_root}/wintun-${WINTUN_VERSION}.zip"
  local dll_path="${cache_root}/amd64/wintun.dll"
  local actual_sha

  mkdir -p "${cache_root}"
  if [[ ! -f "${zip_path}" ]]; then
    download_wintun_zip "${zip_path}"
  fi

  actual_sha="$(sha256_file "${zip_path}")"
  if [[ "${actual_sha}" != "${WINTUN_SHA256}" ]]; then
    rm -f "${zip_path}"
    download_wintun_zip "${zip_path}"
    actual_sha="$(sha256_file "${zip_path}")"
    if [[ "${actual_sha}" != "${WINTUN_SHA256}" ]]; then
      echo "wintun archive hash mismatch for ${zip_path}" >&2
      exit 1
    fi
  fi

  if [[ ! -f "${dll_path}" ]]; then
    extract_wintun_dll "${zip_path}" "${dll_path}"
  fi

  echo "${dll_path}"
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_command go
require_command git
require_command python3
require_command powershell.exe
require_command rsync
require_command wslpath

if [[ ! -d /mnt/e/Projects ]]; then
  echo "expected Windows mirror root at /mnt/e/Projects (E:\\Projects)" >&2
  exit 1
fi

if [[ ! -f "${VERSION_MANIFEST}" ]]; then
  echo "version manifest not found: ${VERSION_MANIFEST}" >&2
  exit 1
fi

mapfile -t VERSION_FIELDS < <(
  python3 -c '
import json
import pathlib
import sys

manifest = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
product = str(manifest.get("product", "")).strip()
version = str(manifest.get("version", "")).strip()
build_number = str(manifest.get("build_number", "")).strip()

if not product:
    raise SystemExit("version manifest missing product")
if not version:
    raise SystemExit("version manifest missing version")
if not build_number:
    raise SystemExit("version manifest missing build_number")

print(product)
print(version)
print(build_number)
' "${VERSION_MANIFEST}"
)

PRODUCT_NAME="${VERSION_FIELDS[0]}"
PRODUCT_VERSION="${VERSION_FIELDS[1]}"
BUILD_NUMBER="${VERSION_FIELDS[2]}"
REVISION="$(git -C "${ROOT_DIR}" rev-parse --short=12 HEAD)"
DIRTY="false"
if [[ -n "$(git -C "${ROOT_DIR}" status --porcelain --untracked-files=no)" ]]; then
  DIRTY="true"
fi
BUILT_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
WINDOWS_GUI_BUILD_METADATA="${ROOT_DIR}/dist/build/windows-gui-build-metadata.json"

phase_started_at=$SECONDS
log_phase "sync Flutter version assets"
python3 "${ROOT_DIR}/scripts/sync-version-assets.py" --repo-root "${ROOT_DIR}"
phase_complete "sync Flutter version assets" "${phase_started_at}"

mkdir -p "$(dirname "${WINDOWS_GUI_BUILD_METADATA}")"
phase_started_at=$SECONDS
log_phase "write Windows GUI build metadata"
python3 -c '
import json
import pathlib
import sys

payload = {
    "product": sys.argv[2],
    "version": sys.argv[3],
    "build_number": sys.argv[4],
    "revision": sys.argv[5],
    "dirty": sys.argv[6].lower() == "true",
    "built_at": sys.argv[7],
    "role": "gui_shell",
    "target": "windows/x64",
}
path = pathlib.Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${WINDOWS_GUI_BUILD_METADATA}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${REVISION}" "${DIRTY}" "${BUILT_AT}"
phase_complete "write Windows GUI build metadata" "${phase_started_at}"

phase_started_at=$SECONDS
log_phase "build Go sidecar artifacts for windows/amd64"
"${ROOT_DIR}/scripts/build-go-matrix.sh" windows/amd64
phase_complete "build Go sidecar artifacts for windows/amd64" "${phase_started_at}"

phase_started_at=$SECONDS
log_phase "prepare official wintun.dll cache"
local_wintun_dll="$(ensure_wintun_dll)"
phase_complete "prepare official wintun.dll cache" "${phase_started_at}"

mkdir -p "${WINDOWS_MIRROR_UNIX}"

mirror_windows_path="$(wslpath -w "${WINDOWS_MIRROR_UNIX}")"
clientd_windows_path="$(wslpath -w "${WINDOWS_MIRROR_UNIX}/dist/go/windows-amd64/clientd.exe")"
build_script_windows_path="$(wslpath -w "${WINDOWS_MIRROR_UNIX}/scripts/build-gui-windows.ps1")"
wintun_dll_windows_path="$(wslpath -w "${WINDOWS_MIRROR_UNIX}/dist/build/vendor/wintun/${WINTUN_VERSION}/amd64/wintun.dll")"

readonly MIRROR_SYNC_EXCLUDES=(
  ".git"
  ".beads"
  ".dart_tool"
  "artifacts"
  "dist/mobile"
  "dist/windows-gui"
  "desktop/gui_shell/.dart_tool"
  "desktop/gui_shell/build"
  "desktop/gui_shell/.idea"
  "desktop/gui_shell/linux/flutter/ephemeral"
  "desktop/gui_shell/macos/Flutter/ephemeral"
  "desktop/gui_shell/windows/flutter/ephemeral"
  "mobile/gui_shell/.dart_tool"
  "mobile/gui_shell/build"
  "mobile/gui_shell/.idea"
  "mobile/gui_shell/android/.gradle"
  "packages/flutter_shell_core/.dart_tool"
  "packages/flutter_shell_core/build"
)

phase_started_at=$SECONDS
log_phase "sync repository into Windows mirror"
echo "    source: ${ROOT_DIR}"
echo "    mirror: ${WINDOWS_MIRROR_UNIX}"
echo "    excluded generated dirs: ${#MIRROR_SYNC_EXCLUDES[@]}"
rsync_args=(
  -a
  --delete
)
for rel_path in "${MIRROR_SYNC_EXCLUDES[@]}"; do
  rsync_args+=(--exclude="${rel_path}")
done
rsync_args+=(--exclude="turnlab-shell")
rsync "${rsync_args[@]}" "${ROOT_DIR}/" "${WINDOWS_MIRROR_UNIX}/"
phase_complete "sync repository into Windows mirror" "${phase_started_at}"

phase_started_at=$SECONDS
log_phase "build Windows GUI in mirror"
powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "${build_script_windows_path}" \
  -RepoRoot "${mirror_windows_path}" \
  -ClientdPath "${clientd_windows_path}" \
  -WintunDllPath "${wintun_dll_windows_path}" \
  -ProductName "${PRODUCT_NAME}" \
  -ProductVersion "${PRODUCT_VERSION}" \
  -BuildNumber "${BUILD_NUMBER}" \
  -Revision "${REVISION}" \
  -Dirty "${DIRTY}" \
  -BuiltAt "${BUILT_AT}"
phase_complete "build Windows GUI in mirror" "${phase_started_at}"

phase_started_at=$SECONDS
log_phase "sync staged Windows GUI bundle back into WSL checkout"
if [[ ! -d "${WINDOWS_MIRROR_UNIX}/dist/windows-gui" ]]; then
  echo "windows GUI bundle not found in mirror dist: ${WINDOWS_MIRROR_UNIX}/dist/windows-gui" >&2
  exit 1
fi
mkdir -p "${ROOT_DIR}/dist/windows-gui"
rsync -a --delete "${WINDOWS_MIRROR_UNIX}/dist/windows-gui/" "${ROOT_DIR}/dist/windows-gui/"
phase_complete "sync staged Windows GUI bundle back into WSL checkout" "${phase_started_at}"

echo "staged Windows GUI bundle under ${ROOT_DIR}/dist/windows-gui"
