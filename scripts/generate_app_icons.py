#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path

from PIL import Image


REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_ICON = REPO_ROOT / "branding/source/app_icon.png"


def resized(image: Image.Image, size: int) -> Image.Image:
    return image.resize((size, size), Image.Resampling.LANCZOS)


def ensure_parent(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)


def load_master_icon() -> Image.Image:
    if not SOURCE_ICON.is_file():
        raise SystemExit(f"canonical icon source not found: {SOURCE_ICON}")
    return Image.open(SOURCE_ICON).convert("RGBA")


def write_png(master: Image.Image, path: Path, size: int) -> None:
    ensure_parent(path)
    resized(master, size).save(path)


def generate_android(master: Image.Image) -> None:
    base = REPO_ROOT / "mobile/gui_shell/android/app/src/main/res"
    sizes = {
        "mipmap-mdpi/ic_launcher.png": 48,
        "mipmap-hdpi/ic_launcher.png": 72,
        "mipmap-xhdpi/ic_launcher.png": 96,
        "mipmap-xxhdpi/ic_launcher.png": 144,
        "mipmap-xxxhdpi/ic_launcher.png": 192,
    }
    for relative, size in sizes.items():
        write_png(master, base / relative, size)


def generate_ios(master: Image.Image) -> None:
    base = REPO_ROOT / "mobile/gui_shell/ios/Runner/Assets.xcassets/AppIcon.appiconset"
    sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for relative, size in sizes.items():
        write_png(master, base / relative, size)


def generate_macos(master: Image.Image) -> None:
    base = REPO_ROOT / "desktop/gui_shell/macos/Runner/Assets.xcassets/AppIcon.appiconset"
    sizes = {
        "app_icon_16.png": 16,
        "app_icon_32.png": 32,
        "app_icon_64.png": 64,
        "app_icon_128.png": 128,
        "app_icon_256.png": 256,
        "app_icon_512.png": 512,
        "app_icon_1024.png": 1024,
    }
    for relative, size in sizes.items():
        write_png(master, base / relative, size)


def generate_windows(master: Image.Image) -> None:
    icon_path = REPO_ROOT / "desktop/gui_shell/windows/runner/resources/app_icon.ico"
    ensure_parent(icon_path)
    master.save(
        icon_path,
        format="ICO",
        sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )


def generate_linux_asset(master: Image.Image) -> None:
    write_png(
        master,
        REPO_ROOT / "desktop/gui_shell/assets/branding/app_icon_256.png",
        256,
    )


def generate_master(master: Image.Image) -> None:
    write_png(master, REPO_ROOT / "branding/generated/app_icon_1024.png", 1024)
    write_png(master, REPO_ROOT / "branding/generated/app_icon_512.png", 512)
    write_png(master, REPO_ROOT / "branding/generated/app_icon_256.png", 256)


def main() -> None:
    master = load_master_icon()
    generate_master(master)
    generate_android(master)
    generate_ios(master)
    generate_macos(master)
    generate_windows(master)
    generate_linux_asset(master)
    print(f"generated app icons from canonical source {SOURCE_ICON}")


if __name__ == "__main__":
    main()
