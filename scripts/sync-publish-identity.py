#!/usr/bin/env python3
import argparse
import json
import pathlib
import re
import shutil
import sys


def load_manifest(path: pathlib.Path) -> dict[str, dict[str, str]]:
    manifest = json.loads(path.read_text(encoding="utf-8"))

    def require(platform: str, key: str) -> str:
        value = str(manifest.get(platform, {}).get(key, "")).strip()
        if not value:
            raise SystemExit(
                f"publish identity manifest missing {platform}.{key}: {path}"
            )
        return value

    return {
        "android": {
            "application_id": require("android", "application_id"),
            "namespace": require("android", "namespace"),
            "kotlin_package": require("android", "kotlin_package"),
        },
        "ios": {
            "bundle_id": require("ios", "bundle_id"),
            "tests_bundle_id": require("ios", "tests_bundle_id"),
        },
        "macos": {
            "bundle_id": require("macos", "bundle_id"),
            "tests_bundle_id": require("macos", "tests_bundle_id"),
        },
        "linux": {
            "application_id": require("linux", "application_id"),
        },
    }


def replace_once(
    path: pathlib.Path,
    content: str,
    pattern: str,
    replacement: str,
    label: str,
) -> str:
    next_content, count = re.subn(pattern, replacement, content, count=1)
    if count != 1:
        raise SystemExit(f"{label} not found in {path}")
    return next_content


def write_or_check(path: pathlib.Path, current: str, updated: str, check: bool) -> bool:
    if current == updated:
        return False
    if check:
        raise SystemExit(f"{path} is out of sync with publish_identity.json")
    path.write_text(updated, encoding="utf-8")
    return True


def sync_android_gradle(
    path: pathlib.Path,
    android_identity: dict[str, str],
    check: bool,
) -> bool:
    content = path.read_text(encoding="utf-8")
    updated = replace_once(
        path,
        content,
        r'(?m)^(\s*namespace\s*=\s*")[^"]+("\s*)$',
        rf'\1{android_identity["namespace"]}\2',
        "Android namespace",
    )
    updated = replace_once(
        path,
        updated,
        r'(?m)^(\s*applicationId\s*=\s*")[^"]+("\s*)$',
        rf'\1{android_identity["application_id"]}\2',
        "Android applicationId",
    )
    return write_or_check(path, content, updated, check)


def cleanup_empty_dirs(root: pathlib.Path) -> None:
    for candidate in sorted(root.rglob("*"), reverse=True):
        if candidate.is_dir():
            try:
                candidate.rmdir()
            except OSError:
                continue


def sync_android_kotlin(
    kotlin_root: pathlib.Path,
    kotlin_package: str,
    check: bool,
) -> bool:
    files = sorted(kotlin_root.rglob("*.kt"))
    if not files:
        raise SystemExit(f"no Kotlin sources found under {kotlin_root}")

    target_dir = kotlin_root / pathlib.Path(*kotlin_package.split("."))
    changed = False
    package_pattern = r"(?m)^package\s+[^\r\n]+$"
    package_line = f"package {kotlin_package}"

    for path in files:
        content = path.read_text(encoding="utf-8")
        updated, count = re.subn(package_pattern, package_line, content, count=1)
        if count != 1:
            raise SystemExit(f"package declaration not found in {path}")
        desired_path = target_dir / path.name
        if check:
            if updated != content or path != desired_path:
                raise SystemExit(f"{path} is out of sync with publish_identity.json")
            continue

        if updated != content:
            path.write_text(updated, encoding="utf-8")
            changed = True
        if path != desired_path:
            target_dir.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), str(desired_path))
            changed = True

    if changed and not check:
        cleanup_empty_dirs(kotlin_root)
    return changed


def sync_ios_pbxproj(
    path: pathlib.Path,
    ios_identity: dict[str, str],
    check: bool,
) -> bool:
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines(keepends=True)
    changed = False
    bundle_count = 0
    next_lines: list[str] = []
    for line in lines:
        if "PRODUCT_BUNDLE_IDENTIFIER =" in line:
            bundle_count += 1
            prefix = line.split("PRODUCT_BUNDLE_IDENTIFIER =", 1)[0]
            expected_value = (
                ios_identity["tests_bundle_id"]
                if "RunnerTests" in line
                else ios_identity["bundle_id"]
            )
            next_line = f"{prefix}PRODUCT_BUNDLE_IDENTIFIER = {expected_value};\n"
            if next_line != line:
                changed = True
            next_lines.append(next_line)
            continue
        next_lines.append(line)
    if bundle_count == 0:
        raise SystemExit(f"PRODUCT_BUNDLE_IDENTIFIER not found in {path}")
    updated = "".join(next_lines)
    return write_or_check(path, content, updated, check)


def sync_macos_app_info(
    path: pathlib.Path,
    macos_identity: dict[str, str],
    check: bool,
) -> bool:
    content = path.read_text(encoding="utf-8")
    updated = replace_once(
        path,
        content,
        r"(?m)^(PRODUCT_BUNDLE_IDENTIFIER\s*=\s*)[^\r\n]+$",
        rf"\1{macos_identity['bundle_id']}",
        "macOS bundle identifier",
    )
    return write_or_check(path, content, updated, check)


def sync_macos_pbxproj(
    path: pathlib.Path,
    macos_identity: dict[str, str],
    check: bool,
) -> bool:
    content = path.read_text(encoding="utf-8")
    lines = content.splitlines(keepends=True)
    changed = False
    bundle_count = 0
    next_lines: list[str] = []
    for line in lines:
        if "PRODUCT_BUNDLE_IDENTIFIER =" in line:
            bundle_count += 1
            prefix = line.split("PRODUCT_BUNDLE_IDENTIFIER =", 1)[0]
            next_line = (
                f"{prefix}PRODUCT_BUNDLE_IDENTIFIER = "
                f"{macos_identity['tests_bundle_id']};\n"
            )
            if next_line != line:
                changed = True
            next_lines.append(next_line)
            continue
        next_lines.append(line)
    if bundle_count == 0:
        raise SystemExit(f"PRODUCT_BUNDLE_IDENTIFIER not found in {path}")
    updated = "".join(next_lines)
    return write_or_check(path, content, updated, check)


def sync_linux_cmakelists(
    path: pathlib.Path,
    linux_identity: dict[str, str],
    check: bool,
) -> bool:
    content = path.read_text(encoding="utf-8")
    updated = replace_once(
        path,
        content,
        r'(?m)^(\s*set\(APPLICATION_ID\s+")[^"]+("\)\s*)$',
        rf'\1{linux_identity["application_id"]}\2',
        "Linux APPLICATION_ID",
    )
    return write_or_check(path, content, updated, check)


def sync_python_default_package(
    path: pathlib.Path,
    package_name: str,
    check: bool,
) -> bool:
    content = path.read_text(encoding="utf-8")
    updated = replace_once(
        path,
        content,
        r'(?m)^(\s*DEFAULT_APP_PACKAGE\s*=\s*")[^"]+("\s*)$',
        rf'\1{package_name}\2',
        "DEFAULT_APP_PACKAGE",
    )
    return write_or_check(path, content, updated, check)


def sync_android_wg_doc(
    path: pathlib.Path,
    package_name: str,
    check: bool,
) -> bool:
    content = path.read_text(encoding="utf-8")
    updated = replace_once(
        path,
        content,
        r"(?m)^(ExcludedApplications = )\S+(\s*)$",
        rf"\1{package_name}\2",
        "WireGuard excluded application package",
    )
    updated = replace_once(
        path,
        updated,
        r'(?m)^(- auto-launches `?)[^`\s]+(`?\s+if needed\s*)$',
        rf"\1{package_name}\2",
        "Android helper package reference",
    )
    return write_or_check(path, content, updated, check)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--repo-root",
        default=pathlib.Path(__file__).resolve().parents[1],
        type=pathlib.Path,
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()

    repo_root = args.repo_root.resolve()
    manifest = load_manifest(repo_root / "publish_identity.json")

    changed = False
    changed |= sync_android_gradle(
        repo_root / "mobile/gui_shell/android/app/build.gradle.kts",
        manifest["android"],
        args.check,
    )
    changed |= sync_android_kotlin(
        repo_root / "mobile/gui_shell/android/app/src/main/kotlin",
        manifest["android"]["kotlin_package"],
        args.check,
    )
    changed |= sync_ios_pbxproj(
        repo_root / "mobile/gui_shell/ios/Runner.xcodeproj/project.pbxproj",
        manifest["ios"],
        args.check,
    )
    changed |= sync_macos_app_info(
        repo_root / "desktop/gui_shell/macos/Runner/Configs/AppInfo.xcconfig",
        manifest["macos"],
        args.check,
    )
    changed |= sync_macos_pbxproj(
        repo_root / "desktop/gui_shell/macos/Runner.xcodeproj/project.pbxproj",
        manifest["macos"],
        args.check,
    )
    changed |= sync_linux_cmakelists(
        repo_root / "desktop/gui_shell/linux/CMakeLists.txt",
        manifest["linux"],
        args.check,
    )
    changed |= sync_python_default_package(
        repo_root / "scripts/android-phone-session.py",
        manifest["android"]["application_id"],
        args.check,
    )
    changed |= sync_python_default_package(
        repo_root / "scripts/smoke-android-vpn-service.py",
        manifest["android"]["application_id"],
        args.check,
    )
    changed |= sync_android_wg_doc(
        repo_root / "docs/android-wg-phone-poc.md",
        manifest["android"]["application_id"],
        args.check,
    )

    if not args.check and changed:
        print("Synchronized publish-facing native identifiers from publish_identity.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
