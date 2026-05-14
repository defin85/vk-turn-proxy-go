#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_MANIFEST="${ROOT_DIR}/version.json"

declare -a DEFAULT_TARGETS=(
  "linux/amd64"
  "windows/amd64"
)

declare -a COMMANDS=(
  "clientd"
  "probe"
  "relaydock-linux-tun-helper"
  "tunnel-client"
  "tunnel-server"
  "turnlab-shell"
)

declare -a TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("${DEFAULT_TARGETS[@]}")
fi

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_command git
require_command python3

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

mkdir -p "${ROOT_DIR}/dist/go"

for target in "${TARGETS[@]}"; do
  if [[ "${target}" != */* ]]; then
    echo "invalid target '${target}'; expected <goos>/<goarch>" >&2
    exit 1
  fi

  IFS=/ read -r goos goarch <<<"${target}"
  outdir="${ROOT_DIR}/dist/go/${goos}-${goarch}"
  rm -rf "${outdir}"
  mkdir -p "${outdir}"

  echo "==> building Go commands for ${goos}/${goarch}"
  for command in "${COMMANDS[@]}"; do
    suffix=""
    if [[ "${goos}" == "windows" ]]; then
      suffix=".exe"
    fi

    ldflags="\
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ProductName=${PRODUCT_NAME} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ProductVersion=${PRODUCT_VERSION} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.BuildNumber=${BUILD_NUMBER} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.Revision=${REVISION} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.Dirty=${DIRTY} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.BuiltAt=${BUILT_AT} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ArtifactRole=${command} \
-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ArtifactTarget=${goos}/${goarch}"

    env \
      CGO_ENABLED=0 \
      GOOS="${goos}" \
      GOARCH="${goarch}" \
      go build -trimpath -ldflags "${ldflags}" -o "${outdir}/${command}${suffix}" "./cmd/${command}"
  done
done
