#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_MANIFEST="${ROOT_DIR}/version.json"
LINUX_GUI_BUILD_METADATA="${ROOT_DIR}/dist/build/linux-gui-build-metadata.json"
GUI_ROOT="${ROOT_DIR}/desktop/gui_shell"
VERSION_FILE="${GUI_ROOT}/.flutter-version"
PACKAGE_ASSETS_DIR="${ROOT_DIR}/packaging/linux/ubuntu"
STAGE_DIR="${ROOT_DIR}/dist/linux-gui"
GO_CLIENTD="${ROOT_DIR}/dist/go/linux-amd64/clientd"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

write_metadata() {
  local path="$1"
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
    "target": "linux/x64",
    "package_target": "ubuntu",
    "linux_tun_packaged_target_env": "VKTP_LINUX_PACKAGED_TARGET=ubuntu",
}
path = pathlib.Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${path}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${REVISION}" "${DIRTY}" "${BUILT_AT}"
}

require_command git
require_command python3
require_command flutter
require_command dart

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Linux GUI packaging must run from a Linux host." >&2
  exit 1
fi

if [[ ! -f "${VERSION_MANIFEST}" ]]; then
  echo "version manifest not found: ${VERSION_MANIFEST}" >&2
  exit 1
fi

if [[ ! -f "${VERSION_FILE}" ]]; then
  echo "Flutter version file not found: ${VERSION_FILE}" >&2
  exit 1
fi
REQUIRED_FLUTTER_VERSION="$(tr -d '\r\n' < "${VERSION_FILE}")"

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

FLUTTER_VERSION_TEXT="$(flutter --version)"
if ! grep -Eq "Flutter[[:space:]]+${REQUIRED_FLUTTER_VERSION}\b" <<<"${FLUTTER_VERSION_TEXT}"; then
  echo "Linux Flutter version mismatch. Expected ${REQUIRED_FLUTTER_VERSION} based on ${VERSION_FILE}." >&2
  exit 1
fi

DOCTOR_TEXT="$(flutter doctor -v)"
if ! grep -Fq "Linux toolchain - develop for Linux desktop" <<<"${DOCTOR_TEXT}"; then
  echo "flutter doctor -v did not confirm the required Linux desktop toolchain." >&2
  exit 1
fi

python3 "${ROOT_DIR}/scripts/sync-publish-identity.py" --repo-root "${ROOT_DIR}"
python3 "${ROOT_DIR}/scripts/sync-version-assets.py" --repo-root "${ROOT_DIR}"

ACTUAL_GUI_VERSION="$(
  python3 -c '
import pathlib
import re
import sys

content = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
match = re.search(r"(?m)^version:\s*([^\r\n]+)\s*$", content)
if not match:
    raise SystemExit("pubspec.yaml missing version")
print(match.group(1).strip())
' "${GUI_ROOT}/pubspec.yaml"
)"
EXPECTED_GUI_VERSION="${PRODUCT_VERSION}+${BUILD_NUMBER}"
if [[ "${ACTUAL_GUI_VERSION}" != "${EXPECTED_GUI_VERSION}" ]]; then
  echo "desktop/gui_shell/pubspec.yaml version mismatch. Expected ${EXPECTED_GUI_VERSION}, found ${ACTUAL_GUI_VERSION}." >&2
  exit 1
fi

write_metadata "${LINUX_GUI_BUILD_METADATA}"

"${ROOT_DIR}/scripts/build-go-matrix.sh" linux/amd64

( cd "${ROOT_DIR}" && dart pub get )
( cd "${ROOT_DIR}" && dart pub workspace list )

rm -rf "${GUI_ROOT}/build/linux"
(
  cd "${GUI_ROOT}"
  flutter build linux \
    --release \
    --build-name "${PRODUCT_VERSION}" \
    --build-number "${BUILD_NUMBER}" \
    --dart-define="VKTP_PRODUCT_NAME=${PRODUCT_NAME}" \
    --dart-define="VKTP_PRODUCT_VERSION=${PRODUCT_VERSION}" \
    --dart-define="VKTP_BUILD_NUMBER=${BUILD_NUMBER}" \
    --dart-define="VKTP_REVISION=${REVISION}" \
    --dart-define="VKTP_DIRTY=${DIRTY}" \
    --dart-define="VKTP_BUILT_AT=${BUILT_AT}" \
    --dart-define="VKTP_ARTIFACT_ROLE=gui_shell" \
    --dart-define="VKTP_ARTIFACT_TARGET=linux/x64"
)

BUNDLE_DIR="${GUI_ROOT}/build/linux/x64/release/bundle"
if [[ ! -x "${BUNDLE_DIR}/relaydock" ]]; then
  echo "expected Linux GUI executable not found after build: ${BUNDLE_DIR}/relaydock" >&2
  exit 1
fi
if [[ ! -x "${GO_CLIENTD}" ]]; then
  echo "expected Go clientd artifact not found after build: ${GO_CLIENTD}" >&2
  exit 1
fi

rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp -a "${BUNDLE_DIR}/." "${STAGE_DIR}/"

install -d -m 0755 "${STAGE_DIR}/libexec"
install -d -m 0755 "${STAGE_DIR}/share/applications"
install -d -m 0755 "${STAGE_DIR}/share/icons/hicolor/256x256/apps"
install -d -m 0755 "${STAGE_DIR}/share/polkit-1/actions"
install -m 0755 "${GO_CLIENTD}" "${STAGE_DIR}/libexec/clientd"
install -m 0755 "${PACKAGE_ASSETS_DIR}/clientd-launcher" "${STAGE_DIR}/clientd"
install -m 0755 "${PACKAGE_ASSETS_DIR}/relaydock-clientd-linux-tun" "${STAGE_DIR}/libexec/relaydock-clientd-linux-tun"
install -m 0644 "${PACKAGE_ASSETS_DIR}/com.defin85.relaydock.desktop" "${STAGE_DIR}/share/applications/com.defin85.relaydock.desktop"
install -m 0644 "${GUI_ROOT}/assets/branding/app_icon_256.png" "${STAGE_DIR}/share/icons/hicolor/256x256/apps/com.defin85.relaydock.png"
install -m 0644 "${PACKAGE_ASSETS_DIR}/com.defin85.relaydock.linux-tun.policy" "${STAGE_DIR}/share/polkit-1/actions/com.defin85.relaydock.linux-tun.policy"
install -m 0755 "${PACKAGE_ASSETS_DIR}/install-ubuntu.sh" "${STAGE_DIR}/install-ubuntu.sh"
write_metadata "${STAGE_DIR}/build-metadata.json"

echo "staged Ubuntu Linux GUI package under ${STAGE_DIR}"
echo "install on Ubuntu with: sudo ${STAGE_DIR}/install-ubuntu.sh"
