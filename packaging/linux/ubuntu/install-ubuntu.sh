#!/usr/bin/env bash
set -euo pipefail

PACKAGE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${INSTALL_ROOT:-/opt/relaydock}"
DESKTOP_ENTRY_DIR="${DESKTOP_ENTRY_DIR:-/usr/share/applications}"
ICON_THEME_DIR="${ICON_THEME_DIR:-/usr/share/icons/hicolor}"
POLKIT_ACTION_DIR="${POLKIT_ACTION_DIR:-/usr/share/polkit-1/actions}"
DESKTOP_ENTRY_NAME="com.defin85.relaydock.desktop"
APP_ICON_NAME="com.defin85.relaydock.png"
POLICY_NAME="com.defin85.relaydock.linux-tun.policy"

fail() {
  echo "$1" >&2
  exit 1
}

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  if [[ "${ID:-}" != "ubuntu" && " ${ID_LIKE:-} " != *" ubuntu "* ]]; then
    fail "RelayDock linux_tun packaged support is currently limited to Ubuntu targets."
  fi
else
  fail "Cannot verify Ubuntu target because /etc/os-release is not readable."
fi

if [[ "$(id -u)" -ne 0 ]]; then
  if ! command -v sudo >/dev/null 2>&1; then
    fail "Run this installer as root or install sudo."
  fi
  exec sudo \
    INSTALL_ROOT="${INSTALL_ROOT}" \
    DESKTOP_ENTRY_DIR="${DESKTOP_ENTRY_DIR}" \
    ICON_THEME_DIR="${ICON_THEME_DIR}" \
    POLKIT_ACTION_DIR="${POLKIT_ACTION_DIR}" \
    bash "$0" "$@"
fi

case "${INSTALL_ROOT}" in
  ""|"/"|"/opt"|"/usr"|"/home"|"/var")
    fail "Refusing unsafe INSTALL_ROOT=${INSTALL_ROOT}"
    ;;
esac
if [[ "${INSTALL_ROOT}" != "/opt/relaydock" ]]; then
  fail "RelayDock linux_tun support is currently tied to INSTALL_ROOT=/opt/relaydock for polkit metadata."
fi

for required in \
  "${PACKAGE_DIR}/relaydock" \
  "${PACKAGE_DIR}/clientd" \
  "${PACKAGE_DIR}/libexec/clientd" \
  "${PACKAGE_DIR}/libexec/relaydock-linux-tun-helper" \
  "${PACKAGE_DIR}/share/applications/${DESKTOP_ENTRY_NAME}" \
  "${PACKAGE_DIR}/share/icons/hicolor/256x256/apps/${APP_ICON_NAME}" \
  "${PACKAGE_DIR}/share/polkit-1/actions/${POLICY_NAME}"; do
  if [[ ! -e "${required}" ]]; then
    fail "Packaged RelayDock file is missing: ${required}"
  fi
done

rm -rf "${INSTALL_ROOT}"
install -d -m 0755 "${INSTALL_ROOT}"
cp -a "${PACKAGE_DIR}/." "${INSTALL_ROOT}/"
chown -R root:root "${INSTALL_ROOT}"
chmod 0755 "${INSTALL_ROOT}/clientd"
chmod 0755 "${INSTALL_ROOT}/libexec/clientd"
chmod 0755 "${INSTALL_ROOT}/libexec/relaydock-linux-tun-helper"

install -d -m 0755 "${DESKTOP_ENTRY_DIR}"
install -m 0644 \
  "${PACKAGE_DIR}/share/applications/${DESKTOP_ENTRY_NAME}" \
  "${DESKTOP_ENTRY_DIR}/${DESKTOP_ENTRY_NAME}"

install -d -m 0755 "${ICON_THEME_DIR}/256x256/apps"
install -m 0644 \
  "${PACKAGE_DIR}/share/icons/hicolor/256x256/apps/${APP_ICON_NAME}" \
  "${ICON_THEME_DIR}/256x256/apps/${APP_ICON_NAME}"

install -d -m 0755 "${POLKIT_ACTION_DIR}"
install -m 0644 \
  "${PACKAGE_DIR}/share/polkit-1/actions/${POLICY_NAME}" \
  "${POLKIT_ACTION_DIR}/${POLICY_NAME}"

if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database "${DESKTOP_ENTRY_DIR}" >/dev/null 2>&1 || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1 && [[ -f "${ICON_THEME_DIR}/index.theme" ]]; then
  gtk-update-icon-cache -q -t -f "${ICON_THEME_DIR}" >/dev/null 2>&1 || true
fi

if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]] && command -v getent >/dev/null 2>&1; then
  USER_RECORD="$(getent passwd "${SUDO_USER}" || true)"
  USER_HOME="$(printf '%s' "${USER_RECORD}" | cut -d: -f6)"
  USER_GROUP="$(id -gn "${SUDO_USER}" 2>/dev/null || printf '%s' "${SUDO_USER}")"
  USER_DESKTOP_DIR="${USER_HOME}/.local/share/applications"
  USER_DESKTOP_ENTRY="${USER_DESKTOP_DIR}/${DESKTOP_ENTRY_NAME}"
  if [[ -n "${USER_HOME}" && -f "${USER_DESKTOP_ENTRY}" ]] &&
    ! { grep -Fq "Exec=${INSTALL_ROOT}/relaydock" "${USER_DESKTOP_ENTRY}" &&
      grep -Fq "Icon=com.defin85.relaydock" "${USER_DESKTOP_ENTRY}" &&
      grep -Fq "Categories=Network;RemoteAccess;" "${USER_DESKTOP_ENTRY}"; } &&
    grep -Eq '^(Name=RelayDock|Exec=.*/relaydock)' "${USER_DESKTOP_ENTRY}"; then
    install -d -m 0755 -o "${SUDO_USER}" -g "${USER_GROUP}" "${USER_DESKTOP_DIR}"
    install -m 0644 -o "${SUDO_USER}" -g "${USER_GROUP}" \
      "${PACKAGE_DIR}/share/applications/${DESKTOP_ENTRY_NAME}" \
      "${USER_DESKTOP_ENTRY}"
  fi
fi

echo "RelayDock Ubuntu linux_tun package installed under ${INSTALL_ROOT}"
echo "Launch the GUI with ${INSTALL_ROOT}/relaydock"
