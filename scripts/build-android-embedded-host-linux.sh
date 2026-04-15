#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_MANIFEST="${ROOT_DIR}/version.json"
ANDROID_HOST_BUILD_METADATA="${ROOT_DIR}/dist/build/android-embedded-host-build-metadata.json"
ANDROID_API_LEVEL="${ANDROID_API_LEVEL:-21}"
ANDROID_DEV_WIREGUARD_PROFILE_DEFAULT="${HOME}/.local/state/vk-turn-proxy-go/wg/phone1.conf"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_command git
require_command python3
require_command go

if [[ ! -f "${VERSION_MANIFEST}" ]]; then
  echo "version manifest not found: ${VERSION_MANIFEST}" >&2
  exit 1
fi

if [[ -n "${ANDROID_NDK_HOME:-}" && -d "${ANDROID_NDK_HOME}" ]]; then
  NDK_ROOT="${ANDROID_NDK_HOME}"
else
  SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -z "${SDK_ROOT}" || ! -d "${SDK_ROOT}" ]]; then
    echo "ANDROID_SDK_ROOT or ANDROID_HOME must point to a Linux Android SDK" >&2
    exit 1
  fi
  NDK_ROOT="${SDK_ROOT}/ndk/28.2.13676358"
fi

TOOLCHAIN_ROOT="${NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin"
if [[ ! -d "${TOOLCHAIN_ROOT}" ]]; then
  echo "expected Android NDK LLVM toolchain under ${TOOLCHAIN_ROOT}" >&2
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

mkdir -p "$(dirname "${ANDROID_HOST_BUILD_METADATA}")"
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
    "role": "android_embedded_host",
    "target": "android/embedded",
}
path = pathlib.Path(sys.argv[1])
path.parent.mkdir(parents=True, exist_ok=True)
path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
' "${ANDROID_HOST_BUILD_METADATA}" "${PRODUCT_NAME}" "${PRODUCT_VERSION}" "${BUILD_NUMBER}" "${REVISION}" "${DIRTY}" "${BUILT_AT}"

OUTPUT_ROOT="${ROOT_DIR}/dist/mobile/android-embedded-host"
JNI_LIBS_ROOT="${OUTPUT_ROOT}/jniLibs"
INCLUDE_ROOT="${OUTPUT_ROOT}/include"
ASSETS_ROOT="${OUTPUT_ROOT}/assets"
rm -rf "${OUTPUT_ROOT}"
mkdir -p "${JNI_LIBS_ROOT}" "${INCLUDE_ROOT}" "${ASSETS_ROOT}"

build_one() {
  local abi="$1"
  local goarch="$2"
  local compiler="$3"
  local artifact_target="$4"
  local goarm="${5:-}"
  local abi_dir="${JNI_LIBS_ROOT}/${abi}"
  local output_lib="${abi_dir}/libvk_turn_mobile_host.so"
  local header_path="${abi_dir}/libvk_turn_mobile_host.h"
  local ldflags

  if [[ ! -x "${compiler}" ]]; then
    echo "expected Android compiler not found: ${compiler}" >&2
    exit 1
  fi

  mkdir -p "${abi_dir}"
  ldflags=$(
    cat <<EOF
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ProductName=${PRODUCT_NAME} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ProductVersion=${PRODUCT_VERSION} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.BuildNumber=${BUILD_NUMBER} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.Revision=${REVISION} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.Dirty=${DIRTY} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.BuiltAt=${BUILT_AT} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ArtifactRole=android_embedded_host \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ArtifactTarget=${artifact_target}
EOF
  )

  (
    cd "${ROOT_DIR}"
    export CGO_ENABLED=1
    export GOOS=android
    export GOARCH="${goarch}"
    export CC="${compiler}"
    if [[ -n "${goarm}" ]]; then
      export GOARM="${goarm}"
    fi
    go build -trimpath -buildmode=c-shared -ldflags "${ldflags}" -o "${output_lib}" ./cmd/android-mobile-host
  )

  if [[ ! -f "${header_path}" ]]; then
    echo "generated header missing: ${header_path}" >&2
    exit 1
  fi
  cp "${header_path}" "${INCLUDE_ROOT}/android_mobile_host.h"
}

build_one "arm64-v8a" "arm64" "${TOOLCHAIN_ROOT}/aarch64-linux-android${ANDROID_API_LEVEL}-clang" "android/arm64"
build_one "armeabi-v7a" "arm" "${TOOLCHAIN_ROOT}/armv7a-linux-androideabi${ANDROID_API_LEVEL}-clang" "android/arm" "7"
build_one "x86_64" "amd64" "${TOOLCHAIN_ROOT}/x86_64-linux-android${ANDROID_API_LEVEL}-clang" "android/amd64"

ANDROID_DEV_WIREGUARD_PROFILE="${VKTP_ANDROID_WIREGUARD_PROFILE:-${ANDROID_DEV_WIREGUARD_PROFILE_DEFAULT}}"
if [[ -f "${ANDROID_DEV_WIREGUARD_PROFILE}" ]]; then
  mkdir -p "${ASSETS_ROOT}/wireguard"
  cp "${ANDROID_DEV_WIREGUARD_PROFILE}" "${ASSETS_ROOT}/wireguard/phone1.conf"
  echo "staged Android dev WireGuard profile from ${ANDROID_DEV_WIREGUARD_PROFILE}"
fi

echo "staged Android embedded host under ${OUTPUT_ROOT}"
