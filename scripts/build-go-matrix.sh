#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

declare -a DEFAULT_TARGETS=(
  "linux/amd64"
  "windows/amd64"
)

declare -a COMMANDS=(
  "clientd"
  "probe"
  "tunnel-client"
  "tunnel-server"
  "turnlab-shell"
)

declare -a TARGETS=("$@")
if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS=("${DEFAULT_TARGETS[@]}")
fi

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

    env \
      CGO_ENABLED=0 \
      GOOS="${goos}" \
      GOARCH="${goarch}" \
      go build -trimpath -o "${outdir}/${command}${suffix}" "./cmd/${command}"
  done
done
