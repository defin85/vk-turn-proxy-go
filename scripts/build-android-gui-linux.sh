#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_MANIFEST="${ROOT_DIR}/version.json"
ANDROID_GUI_BUILD_METADATA="${ROOT_DIR}/dist/build/android-gui-build-metadata.json"
GUI_ROOT="${ROOT_DIR}/mobile/gui_shell"
ANDROID_ROOT="${GUI_ROOT}/android"
VERSION_FILE="${GUI_ROOT}/.flutter-version"
DEFAULT_ANDROID_SDK_ROOT="${HOME}/.local/share/android-sdk"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_command git
require_command python3
require_command flutter
require_command dart
require_command unzip

if [[ ! -f "${VERSION_MANIFEST}" ]]; then
  echo "version manifest not found: ${VERSION_MANIFEST}" >&2
  exit 1
fi

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-${DEFAULT_ANDROID_SDK_ROOT}}}"
if [[ ! -d "${ANDROID_SDK_ROOT}" ]]; then
  echo "Android SDK root not found: ${ANDROID_SDK_ROOT}" >&2
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

FLUTTER_BIN="$(readlink -f "$(command -v flutter)")"
FLUTTER_ROOT="$(cd "$(dirname "${FLUTTER_BIN}")/.." && pwd)"

FLUTTER_VERSION_TEXT="$(flutter --version)"
if ! grep -Eq "Flutter[[:space:]]+${REQUIRED_FLUTTER_VERSION}\b" <<<"${FLUTTER_VERSION_TEXT}"; then
  echo "Linux Flutter version mismatch. Expected ${REQUIRED_FLUTTER_VERSION} based on ${VERSION_FILE}." >&2
  exit 1
fi

DOCTOR_TEXT="$(flutter doctor -v)"
if ! grep -Fq "[✓] Android toolchain - develop for Android devices" <<<"${DOCTOR_TEXT}"; then
  echo "flutter doctor -v did not confirm the required Android toolchain." >&2
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
  echo "mobile/gui_shell/pubspec.yaml version mismatch. Expected ${EXPECTED_GUI_VERSION}, found ${ACTUAL_GUI_VERSION}." >&2
  exit 1
fi

mkdir -p "$(dirname "${ANDROID_GUI_BUILD_METADATA}")"
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
    "role": "mobile_gui_shell",
    "target": "android/debug",
}
path = pathlib.Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${ANDROID_GUI_BUILD_METADATA}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${REVISION}" "${DIRTY}" "${BUILT_AT}"

cat > "${ANDROID_ROOT}/local.properties" <<EOF
sdk.dir=${ANDROID_SDK_ROOT}
flutter.sdk=${FLUTTER_ROOT}
EOF

( cd "${ROOT_DIR}" && dart pub get )
( cd "${ROOT_DIR}" && dart pub workspace list )
bash "${ROOT_DIR}/scripts/build-android-embedded-host-linux.sh"

(
  cd "${GUI_ROOT}"
  flutter build apk \
    --debug \
    --build-name "${PRODUCT_VERSION}" \
    --build-number "${BUILD_NUMBER}" \
    --dart-define="VKTP_PRODUCT_NAME=${PRODUCT_NAME}" \
    --dart-define="VKTP_PRODUCT_VERSION=${PRODUCT_VERSION}" \
    --dart-define="VKTP_BUILD_NUMBER=${BUILD_NUMBER}" \
    --dart-define="VKTP_REVISION=${REVISION}" \
    --dart-define="VKTP_DIRTY=${DIRTY}" \
    --dart-define="VKTP_BUILT_AT=${BUILT_AT}" \
    --dart-define="VKTP_ARTIFACT_ROLE=mobile_gui_shell" \
    --dart-define="VKTP_ARTIFACT_TARGET=android/debug"
)

APK_PATH="${GUI_ROOT}/build/app/outputs/flutter-apk/app-debug.apk"
if [[ ! -f "${APK_PATH}" ]]; then
  echo "expected Android APK not found after build: ${APK_PATH}" >&2
  exit 1
fi

APK_ENTRIES="$(unzip -l "${APK_PATH}")"
for expected_entry in \
  "lib/arm64-v8a/libandroid_mobile_host_jni.so" \
  "lib/arm64-v8a/libvk_turn_mobile_host.so" \
  "lib/armeabi-v7a/libandroid_mobile_host_jni.so" \
  "lib/armeabi-v7a/libvk_turn_mobile_host.so" \
  "lib/x86_64/libandroid_mobile_host_jni.so" \
  "lib/x86_64/libvk_turn_mobile_host.so"; do
  if ! grep -Fq "${expected_entry}" <<<"${APK_ENTRIES}"; then
    echo "expected APK entry not found: ${expected_entry}" >&2
    exit 1
  fi
done
if [[ -f "${ROOT_DIR}/dist/mobile/android-embedded-host/assets/wireguard/phone1.conf" ]]; then
  if ! grep -Fq "assets/wireguard/phone1.conf" <<<"${APK_ENTRIES}"; then
    echo "expected packaged Android WireGuard profile asset not found in APK" >&2
    exit 1
  fi
fi

STAGE_DIR="${ROOT_DIR}/dist/mobile/android-gui-shell"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp "${APK_PATH}" "${STAGE_DIR}/app-debug.apk"
sha1sum "${STAGE_DIR}/app-debug.apk" | awk '{print $1}' > "${STAGE_DIR}/app-debug.apk.sha1"
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
    "role": "mobile_gui_shell",
    "target": "android/debug",
}
path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${STAGE_DIR}/build-metadata.json" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${REVISION}" "${DIRTY}" "${BUILT_AT}"

echo "staged Android GUI APK under ${STAGE_DIR}"
