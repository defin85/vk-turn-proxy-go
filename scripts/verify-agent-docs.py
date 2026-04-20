#!/usr/bin/env python3

from __future__ import annotations

import re
import shutil
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]

DOC_FILES = [
    Path("AGENTS.md"),
    Path("README.md"),
    Path("code_review.md"),
    Path("desktop/gui_shell/AGENTS.md"),
    Path("desktop/gui_shell/README.md"),
    Path("docs/agent/index.md"),
    Path("docs/agent/architecture-map.md"),
    Path("docs/agent/runtime-surface.md"),
    Path("docs/agent/verification.md"),
    Path("docs/build-workflows.md"),
    Path("mobile/gui_shell/AGENTS.md"),
    Path("mobile/gui_shell/README.md"),
    Path("openspec/AGENTS.md"),
    Path("openspec/project.md"),
    Path("test/compatibility/AGENTS.md"),
    Path("test/compatibility/README.md"),
    Path("test/compatibility/vk/README.md"),
    Path(".agents/skills/vk-turn-desktop-shell/SKILL.md"),
]

MANUAL_PATHS = [
    Path("publish_identity.json"),
    Path("scripts/codex-onboard.sh"),
    Path("scripts/verify-agent-docs.py"),
    Path(".agents/skills/vk-turn-desktop-shell/references/product-rules.md"),
    Path(".agents/skills/vk-turn-desktop-shell/references/repo-entrypoints.md"),
]

PATH_PREFIXES = (
    ".agents/",
    ".github/",
    ".githooks/",
    "AGENTS.md",
    "README.md",
    "code_review.md",
    "cmd/",
    "desktop/",
    "docs/",
    "internal/",
    "mobile/",
    "openspec/",
    "packages/",
    "publish_identity.json",
    "pkg/",
    "scripts/",
    "test/",
    "version.json",
)

SKIP_PREFIXES = (
    "/home/",
    "./",
    "../",
    "http://",
    "https://",
    "ssh ",
    "go ",
    "make ",
    "dart ",
    "flutter ",
    "python ",
    "python3 ",
    "powershell ",
    "bash ",
    "git ",
    "act ",
    "bd ",
    "openspec ",
    "C:\\",
    "E:\\",
    "~",
    "%",
    "@/",
)

BACKTICK_PATTERN = re.compile(r"`([^`]+)`")
ARCHIVE_TBD_PATTERN = "TBD - created by archiving change"


def should_check_token(token: str) -> bool:
    if not token or any(char in token for char in "*<>|"):
        return False
    if "..." in token or any(char.isspace() for char in token):
        return False
    if token.startswith(SKIP_PREFIXES):
        return False
    return token.startswith(PATH_PREFIXES)


def repo_path_from_token(token: str) -> Path:
    return ROOT / token


def run_smoke_check(args: list[str], description: str) -> str | None:
    try:
        completed = subprocess.run(
            args,
            cwd=ROOT,
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError:
        return f"missing command for smoke check ({description}): {args[0]}"
    except subprocess.CalledProcessError as exc:
        output = (exc.stdout + exc.stderr).strip()
        if output:
            output = "\n".join(output.splitlines()[-20:])
            return (
                f"failed smoke check ({description}): {' '.join(args)}\n"
                f"{output}"
            )
        return f"failed smoke check ({description}): {' '.join(args)}"

    if completed.stderr.strip():
        return (
            f"unexpected stderr from smoke check ({description}): {' '.join(args)}\n"
            + "\n".join(completed.stderr.strip().splitlines()[-20:])
        )

    return None


def main() -> int:
    missing: list[str] = []

    for relative_path in DOC_FILES + MANUAL_PATHS:
        path = ROOT / relative_path
        if not path.exists():
            missing.append(f"missing file: {relative_path}")

    for relative_path in DOC_FILES:
        path = ROOT / relative_path
        if not path.exists():
            continue
        text = path.read_text(encoding="utf-8")
        for token in BACKTICK_PATTERN.findall(text):
            if not should_check_token(token):
                continue
            target = repo_path_from_token(token)
            if not target.exists():
                missing.append(f"broken repo path in {relative_path}: {token}")

    for spec_path in sorted((ROOT / "openspec/specs").glob("*/spec.md")):
        text = spec_path.read_text(encoding="utf-8")
        if ARCHIVE_TBD_PATTERN in text:
            missing.append(f"unfinished spec purpose: {spec_path.relative_to(ROOT)}")

    smoke_checks: list[tuple[list[str], str]] = [
        (["bash", "./scripts/codex-onboard.sh"], "fast onboarding"),
        (["make", "-n", "codex-onboard-workflow"], "workflow onboarding make target"),
    ]

    if shutil.which("openspec"):
        smoke_checks.append((["openspec", "list", "--specs"], "openspec spec listing"))

    for args, description in smoke_checks:
        smoke_error = run_smoke_check(args, description)
        if smoke_error:
            missing.append(smoke_error)

    if missing:
        for item in missing:
            print(item, file=sys.stderr)
        return 1

    print("agent docs verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
