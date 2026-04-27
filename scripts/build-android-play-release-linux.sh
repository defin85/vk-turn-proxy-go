#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_MANIFEST="${ROOT_DIR}/version.json"
ANDROID_RELEASE_BUILD_METADATA="${ROOT_DIR}/dist/build/android-play-release-build-metadata.json"
GUI_ROOT="${ROOT_DIR}/mobile/gui_shell"
ANDROID_ROOT="${GUI_ROOT}/android"
VERSION_FILE="${GUI_ROOT}/.flutter-version"
DEFAULT_ANDROID_SDK_ROOT="${HOME}/.local/share/android-sdk"
PLAY_TARGET_SDK_FLOOR="${VKTP_ANDROID_PLAY_TARGET_SDK_FLOOR:-35}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "${value}" ]]; then
    echo "required environment variable not set: ${name}" >&2
    exit 1
  fi
  printf '%s' "${value}"
}

require_command git
require_command python3
require_command flutter
require_command dart
require_command unzip
require_command sha256sum
require_command keytool
require_command jarsigner

UPLOAD_KEYSTORE="$(require_env VKTP_ANDROID_UPLOAD_KEYSTORE)"
UPLOAD_KEY_ALIAS="$(require_env VKTP_ANDROID_UPLOAD_KEY_ALIAS)"
UPLOAD_STORE_PASSWORD="$(require_env VKTP_ANDROID_UPLOAD_STORE_PASSWORD)"
UPLOAD_KEY_PASSWORD="$(require_env VKTP_ANDROID_UPLOAD_KEY_PASSWORD)"

if [[ ! -f "${UPLOAD_KEYSTORE}" ]]; then
  echo "Android upload keystore not found: ${UPLOAD_KEYSTORE}" >&2
  exit 1
fi

UPLOAD_CERT_SHA256="$(
  keytool -list -v \
    -keystore "${UPLOAD_KEYSTORE}" \
    -alias "${UPLOAD_KEY_ALIAS}" \
    -storepass "${UPLOAD_STORE_PASSWORD}" \
    2>/dev/null |
    awk -F': ' '/SHA256:/{print $2; exit}'
)"
if [[ -z "${UPLOAD_CERT_SHA256}" ]]; then
  echo "could not read upload certificate SHA-256 from keystore alias ${UPLOAD_KEY_ALIAS}" >&2
  exit 1
fi

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

cat > "${ANDROID_ROOT}/local.properties" <<EOF
sdk.dir=${ANDROID_SDK_ROOT}
flutter.sdk=${FLUTTER_ROOT}
EOF

( cd "${ROOT_DIR}" && dart pub get )
( cd "${ROOT_DIR}" && dart pub workspace list )

export VKTP_ANDROID_INCLUDE_DEV_WIREGUARD_PROFILE=0
unset VKTP_ANDROID_WIREGUARD_PROFILE
bash "${ROOT_DIR}/scripts/build-android-embedded-host-linux.sh"

EFFECTIVE_TARGET_SDK="$(
  cd "${ANDROID_ROOT}"
  ./gradlew -q :app:printReleaseTargetSdkVersion | tail -n 1
)"
python3 -c '
import sys
target = int(sys.argv[1])
floor = int(sys.argv[2])
if target < floor:
    raise SystemExit(
        f"Android release targetSdkVersion {target} is below repo-managed Play floor {floor}"
    )
' "${EFFECTIVE_TARGET_SDK}" "${PLAY_TARGET_SDK_FLOOR}"

mkdir -p "$(dirname "${ANDROID_RELEASE_BUILD_METADATA}")"
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
    "target": "android/play-release",
    "artifact_type": "android_app_bundle",
    "signing_mode": "upload_key",
    "upload_key_alias": sys.argv[8],
    "upload_certificate_sha256": sys.argv[9],
    "effective_target_sdk": int(sys.argv[10]),
    "target_sdk_floor": int(sys.argv[11]),
}
path = pathlib.Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${ANDROID_RELEASE_BUILD_METADATA}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${REVISION}" "${DIRTY}" "${BUILT_AT}" "${UPLOAD_KEY_ALIAS}" "${UPLOAD_CERT_SHA256}" "${EFFECTIVE_TARGET_SDK}" "${PLAY_TARGET_SDK_FLOOR}"

(
  cd "${GUI_ROOT}"
  flutter build appbundle \
    --release \
    --build-name "${PRODUCT_VERSION}" \
    --build-number "${BUILD_NUMBER}" \
    --dart-define="VKTP_PRODUCT_NAME=${PRODUCT_NAME}" \
    --dart-define="VKTP_PRODUCT_VERSION=${PRODUCT_VERSION}" \
    --dart-define="VKTP_BUILD_NUMBER=${BUILD_NUMBER}" \
    --dart-define="VKTP_REVISION=${REVISION}" \
    --dart-define="VKTP_DIRTY=${DIRTY}" \
    --dart-define="VKTP_BUILT_AT=${BUILT_AT}" \
    --dart-define="VKTP_ARTIFACT_ROLE=mobile_gui_shell" \
    --dart-define="VKTP_ARTIFACT_TARGET=android/play-release"
)

AAB_PATH="${GUI_ROOT}/build/app/outputs/bundle/release/app-release.aab"
if [[ ! -f "${AAB_PATH}" ]]; then
  echo "expected Android App Bundle not found after build: ${AAB_PATH}" >&2
  exit 1
fi

AAB_ENTRIES="$(unzip -l "${AAB_PATH}")"
for expected_entry in \
  "base/lib/arm64-v8a/libandroid_mobile_host_jni.so" \
  "base/lib/arm64-v8a/libvk_turn_mobile_host.so" \
  "base/lib/armeabi-v7a/libandroid_mobile_host_jni.so" \
  "base/lib/armeabi-v7a/libvk_turn_mobile_host.so" \
  "base/lib/x86_64/libandroid_mobile_host_jni.so" \
  "base/lib/x86_64/libvk_turn_mobile_host.so"; do
  if ! grep -Fq "${expected_entry}" <<<"${AAB_ENTRIES}"; then
    echo "expected AAB entry not found: ${expected_entry}" >&2
    exit 1
  fi
done
if grep -Eq '(^|[[:space:]])base/assets/wireguard/phone1\.conf($|[[:space:]])' <<<"${AAB_ENTRIES}"; then
  echo "release AAB contains debug WireGuard seed asset: base/assets/wireguard/phone1.conf" >&2
  exit 1
fi
if grep -Eq '(^|[[:space:]])base/assets/adi-registration\.properties($|[[:space:]])' <<<"${AAB_ENTRIES}"; then
  echo "release AAB contains one-off Play ownership proof asset: base/assets/adi-registration.properties" >&2
  exit 1
fi

jarsigner -verify "${AAB_PATH}" >/dev/null
AAB_CERT_SHA256="$(
  keytool -printcert -jarfile "${AAB_PATH}" 2>/dev/null |
    awk -F': ' '/SHA256:/{print $2; exit}'
)"
if [[ "${AAB_CERT_SHA256}" != "${UPLOAD_CERT_SHA256}" ]]; then
  echo "AAB signer SHA-256 ${AAB_CERT_SHA256:-<missing>} does not match upload certificate ${UPLOAD_CERT_SHA256}" >&2
  exit 1
fi

LOCAL_DELIVERY_ARGS=(--aab "${AAB_PATH}")
if [[ -n "${VKTP_ANDROID_PLAY_RELEASE_DEVICE_ID:-}" ]]; then
  LOCAL_DELIVERY_ARGS+=(--device-id "${VKTP_ANDROID_PLAY_RELEASE_DEVICE_ID}")
elif [[ -n "${VKTP_ANDROID_PLAY_RELEASE_DEVICE_SPEC:-}" ]]; then
  LOCAL_DELIVERY_ARGS+=(--device-spec "${VKTP_ANDROID_PLAY_RELEASE_DEVICE_SPEC}")
fi
bash "${ROOT_DIR}/scripts/verify-android-play-release-local-delivery.sh" "${LOCAL_DELIVERY_ARGS[@]}"

STAGE_DIR="${ROOT_DIR}/dist/mobile/android-play-release"
rm -rf "${STAGE_DIR}"
mkdir -p "${STAGE_DIR}"
cp "${AAB_PATH}" "${STAGE_DIR}/app-release.aab"
sha256sum "${STAGE_DIR}/app-release.aab" | awk '{print $1}' > "${STAGE_DIR}/app-release.aab.sha256"
python3 -c '
import json
import pathlib
import sys

aab = pathlib.Path(sys.argv[12])
sha256_path = pathlib.Path(sys.argv[13])
payload = {
    "product": sys.argv[2],
    "version": sys.argv[3],
    "build_number": sys.argv[4],
    "revision": sys.argv[5],
    "dirty": sys.argv[6].lower() == "true",
    "built_at": sys.argv[7],
    "role": "mobile_gui_shell",
    "target": "android/play-release",
    "artifact_type": "android_app_bundle",
    "artifact": aab.name,
    "artifact_sha256": sha256_path.read_text(encoding="utf-8").strip(),
    "signing_mode": "upload_key",
    "upload_key_alias": sys.argv[8],
    "upload_certificate_sha256": sys.argv[9],
    "effective_target_sdk": int(sys.argv[10]),
    "target_sdk_floor": int(sys.argv[11]),
}
path = pathlib.Path(sys.argv[1])
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${STAGE_DIR}/build-metadata.json" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${REVISION}" "${DIRTY}" "${BUILT_AT}" "${UPLOAD_KEY_ALIAS}" "${UPLOAD_CERT_SHA256}" "${EFFECTIVE_TARGET_SDK}" "${PLAY_TARGET_SDK_FLOOR}" "${STAGE_DIR}/app-release.aab" "${STAGE_DIR}/app-release.aab.sha256"

echo "staged Android Play release AAB under ${STAGE_DIR}"
