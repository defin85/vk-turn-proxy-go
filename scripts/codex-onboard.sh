#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT_DIR"

workflow_mode=false

usage() {
  cat <<'EOF'
Usage: scripts/codex-onboard.sh [--workflow]

  --workflow  Include current git status and Beads workflow context.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow)
      workflow_mode=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

print_section() {
  printf '\n== %s ==\n' "$1"
}

print_section "Repo"
pwd

print_section "Agent Entry Points"
printf '%s\n' \
  "AGENTS.md" \
  "docs/agent/index.md" \
  "docs/agent/runtime-surface.md" \
  "docs/agent/architecture-map.md" \
  "docs/agent/verification.md" \
  "README.md" \
  "openspec/project.md" \
  "openspec/AGENTS.md" \
  "test/compatibility/AGENTS.md" \
  "desktop/gui_shell/AGENTS.md" \
  "mobile/gui_shell/AGENTS.md"
if [ -f .agents/skills/vk-turn-desktop-shell/SKILL.md ]; then
  printf '%s\n' ".agents/skills/vk-turn-desktop-shell/SKILL.md"
fi

print_section "Tool Availability"
for tool in openspec bd go dart flutter act python3; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '%s=available\n' "$tool"
  else
    printf '%s=missing\n' "$tool"
  fi
done

if command -v openspec >/dev/null 2>&1; then
  print_section "OpenSpec Changes"
  openspec list

  print_section "OpenSpec Specs"
  openspec list --specs
fi

if [ "$workflow_mode" = true ]; then
  print_section "Git Status"
  git status --short --branch
fi

if [ "$workflow_mode" = true ] && command -v bd >/dev/null 2>&1; then
  print_section "Beads"
  bd prime || true
fi

if [ "$workflow_mode" = false ]; then
  print_section "Next"
  printf '%s\n' \
    "Need current git status and Beads context? run: make codex-onboard-workflow"
fi
