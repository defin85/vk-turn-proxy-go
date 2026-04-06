#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WINDOWS_MIRROR_UNIX="/mnt/e/Projects/vk-turn-proxy-go"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_command go
require_command powershell.exe
require_command wslpath

if [[ ! -d /mnt/e/Projects ]]; then
  echo "expected Windows mirror root at /mnt/e/Projects (E:\\Projects)" >&2
  exit 1
fi

"${ROOT_DIR}/scripts/build-go-matrix.sh" windows/amd64

mkdir -p "${WINDOWS_MIRROR_UNIX}"

source_windows_path="$(wslpath -w "${ROOT_DIR}")"
mirror_windows_path="$(wslpath -w "${WINDOWS_MIRROR_UNIX}")"
clientd_windows_path="$(wslpath -w "${WINDOWS_MIRROR_UNIX}/dist/go/windows-amd64/clientd.exe")"
build_script_windows_path="$(wslpath -w "${WINDOWS_MIRROR_UNIX}/scripts/build-gui-windows.ps1")"

sync_command="\
\$src='${source_windows_path}'; \
\$dst='${mirror_windows_path}'; \
New-Item -ItemType Directory -Force -Path \$dst | Out-Null; \
\$excludedDirs=@( \
  (Join-Path \$src '.git'), \
  (Join-Path \$src '.beads'), \
  (Join-Path \$src 'dist\\windows-gui'), \
  (Join-Path \$src 'desktop\\gui_shell\\.dart_tool'), \
  (Join-Path \$src 'desktop\\gui_shell\\build'), \
  (Join-Path \$src 'desktop\\gui_shell\\.idea') \
); \
\$args=@(\$src,\$dst,'/MIR','/XD') + \$excludedDirs + @('/XF','turnlab-shell'); \
& robocopy @args; \
if (\$LASTEXITCODE -gt 7) { exit \$LASTEXITCODE }; \
exit 0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "${sync_command}"

powershell.exe -NoProfile -ExecutionPolicy Bypass \
  -File "${build_script_windows_path}" \
  -RepoRoot "${mirror_windows_path}" \
  -ClientdPath "${clientd_windows_path}"

sync_back_command="\
\$src='${mirror_windows_path}\\dist\\windows-gui'; \
\$dst='${source_windows_path}\\dist\\windows-gui'; \
if (-not (Test-Path \$src)) { throw 'windows GUI bundle not found in mirror dist' }; \
New-Item -ItemType Directory -Force -Path \$dst | Out-Null; \
& robocopy \$src \$dst /MIR; \
if (\$LASTEXITCODE -gt 7) { exit \$LASTEXITCODE }; \
exit 0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "${sync_back_command}"
