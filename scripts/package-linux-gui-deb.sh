#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_MANIFEST="${ROOT_DIR}/version.json"
STAGE_DIR="${ROOT_DIR}/dist/linux-gui"
OUT_DIR="${ROOT_DIR}/dist/linux-deb"
WORK_DIR="${ROOT_DIR}/dist/build/linux-deb"
PACKAGE_NAME="relaydock"
DEB_ARCHITECTURE="${DEB_ARCHITECTURE:-amd64}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "required command not found: $1" >&2
    exit 1
  fi
}

require_command dpkg-deb
require_command python3

if [[ ! -f "${VERSION_MANIFEST}" ]]; then
  echo "version manifest not found: ${VERSION_MANIFEST}" >&2
  exit 1
fi

for required in \
  "${STAGE_DIR}/relaydock" \
  "${STAGE_DIR}/clientd" \
  "${STAGE_DIR}/libexec/clientd" \
  "${STAGE_DIR}/libexec/relaydock-clientd-linux-tun" \
  "${STAGE_DIR}/share/applications/com.defin85.relaydock.desktop" \
  "${STAGE_DIR}/share/icons/hicolor/256x256/apps/com.defin85.relaydock.png" \
  "${STAGE_DIR}/share/polkit-1/actions/com.defin85.relaydock.linux-tun.policy" \
  "${STAGE_DIR}/build-metadata.json"; do
  if [[ ! -e "${required}" ]]; then
    echo "Linux GUI stage is incomplete; missing ${required}. Run make build-gui-linux first." >&2
    exit 1
  fi
done

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
DEB_VERSION="${PRODUCT_VERSION}-${BUILD_NUMBER}"
PACKAGE_ROOT="${WORK_DIR}/${PACKAGE_NAME}_${DEB_VERSION}_${DEB_ARCHITECTURE}"
DEBIAN_DIR="${PACKAGE_ROOT}/DEBIAN"

case "${DEB_VERSION}" in
  *[!A-Za-z0-9.+:~_-]*|"")
    echo "invalid Debian package version: ${DEB_VERSION}" >&2
    exit 1
    ;;
esac

rm -rf "${PACKAGE_ROOT}"
mkdir -p "${DEBIAN_DIR}"
install -d -m 0755 "${PACKAGE_ROOT}/opt"
cp -a "${STAGE_DIR}" "${PACKAGE_ROOT}/opt/relaydock"
rm -f "${PACKAGE_ROOT}/opt/relaydock/install-ubuntu.sh"

install -d -m 0755 "${PACKAGE_ROOT}/usr/share/applications"
install -m 0644 \
  "${STAGE_DIR}/share/applications/com.defin85.relaydock.desktop" \
  "${PACKAGE_ROOT}/usr/share/applications/com.defin85.relaydock.desktop"

install -d -m 0755 "${PACKAGE_ROOT}/usr/share/icons/hicolor/256x256/apps"
install -m 0644 \
  "${STAGE_DIR}/share/icons/hicolor/256x256/apps/com.defin85.relaydock.png" \
  "${PACKAGE_ROOT}/usr/share/icons/hicolor/256x256/apps/com.defin85.relaydock.png"

install -d -m 0755 "${PACKAGE_ROOT}/usr/share/polkit-1/actions"
install -m 0644 \
  "${STAGE_DIR}/share/polkit-1/actions/com.defin85.relaydock.linux-tun.policy" \
  "${PACKAGE_ROOT}/usr/share/polkit-1/actions/com.defin85.relaydock.linux-tun.policy"

install -d -m 0700 "${PACKAGE_ROOT}/var/lib/relaydock/vpn-transport-profiles"

INSTALLED_SIZE="$(du -sk "${PACKAGE_ROOT}" | awk '{print $1}')"
cat > "${DEBIAN_DIR}/control" <<EOF
Package: ${PACKAGE_NAME}
Version: ${DEB_VERSION}
Section: net
Priority: optional
Architecture: ${DEB_ARCHITECTURE}
Maintainer: RelayDock Maintainers <noreply@example.invalid>
Depends: bash, libgtk-3-0, libstdc++6, policykit-1 | pkexec
Installed-Size: ${INSTALLED_SIZE}
Homepage: https://github.com/defin85/vk-turn-proxy-go
Description: ${PRODUCT_NAME} desktop VPN relay client
 RelayDock packages the Flutter desktop shell, local clientd sidecar,
 Ubuntu linux_tun privilege wrapper, desktop launcher, icon, and polkit
 metadata into one installable desktop package.
EOF

cat > "${DEBIAN_DIR}/postinst" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1 && [ -f /usr/share/icons/hicolor/index.theme ]; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
exit 0
EOF
chmod 0755 "${DEBIAN_DIR}/postinst"

cat > "${DEBIAN_DIR}/postrm" <<'EOF'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1 && [ -f /usr/share/icons/hicolor/index.theme ]; then
  gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor >/dev/null 2>&1 || true
fi
exit 0
EOF
chmod 0755 "${DEBIAN_DIR}/postrm"

mkdir -p "${OUT_DIR}"
PACKAGE_PATH="${OUT_DIR}/${PACKAGE_NAME}_${DEB_VERSION}_${DEB_ARCHITECTURE}.deb"
rm -f "${PACKAGE_PATH}"
dpkg-deb --root-owner-group --build "${PACKAGE_ROOT}" "${PACKAGE_PATH}"
(
  cd "${OUT_DIR}"
  sha256sum "$(basename "${PACKAGE_PATH}")" > "$(basename "${PACKAGE_PATH}").sha256"
)

echo "staged Debian package at ${PACKAGE_PATH}"
