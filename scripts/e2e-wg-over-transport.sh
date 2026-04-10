#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist/go/linux-amd64"

REMOTE_HOST="${REMOTE_HOST:-vk-turn-proxy-go}"
REMOTE_PUBLIC_HOST="${REMOTE_PUBLIC_HOST:-}"
TURN_LINK="${TURN_LINK:-}"
PROVIDER_NAME="${PROVIDER_NAME:-}"
PROVIDER_LINK="${PROVIDER_LINK:-}"
INTERACTIVE_PROVIDER="${INTERACTIVE_PROVIDER:-false}"
SKIP_PROVIDER_PREFLIGHT="${SKIP_PROVIDER_PREFLIGHT:-false}"

LOCAL_SUDO_PASSWORD="${LOCAL_SUDO_PASSWORD:-}"

LOCAL_TRANSPORT_HOST="${LOCAL_TRANSPORT_HOST:-127.0.0.1}"
LOCAL_TRANSPORT_PORT="${LOCAL_TRANSPORT_PORT:-39000}"
REMOTE_TRANSPORT_PORT="${REMOTE_TRANSPORT_PORT:-56040}"
REMOTE_WG_PORT="${REMOTE_WG_PORT:-51871}"
LOCAL_WG_PORT="${LOCAL_WG_PORT:-51870}"

LOCAL_WG_IF="${LOCAL_WG_IF:-vktpe2ec}"
REMOTE_WG_IF="${REMOTE_WG_IF:-vktpe2es}"
LOCAL_WG_ADDR="${LOCAL_WG_ADDR:-10.231.0.2/24}"
REMOTE_WG_ADDR="${REMOTE_WG_ADDR:-10.231.0.1/24}"
LOCAL_ALLOWED_IP="${LOCAL_ALLOWED_IP:-10.231.0.1/32}"
REMOTE_ALLOWED_IP="${REMOTE_ALLOWED_IP:-10.231.0.2/32}"
WG_MTU="${WG_MTU:-1280}"
PING_COUNT="${PING_COUNT:-3}"

CHECK_ONLY="false"
SKIP_BUILD="false"
RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"

TMP_DIR=""
REMOTE_DIR=""
LOCAL_CLIENT_PID=""
REMOTE_SERVER_PID=""
LOCAL_CLIENT_LOG=""
REMOTE_SERVER_LOG=""

usage() {
  cat <<'EOF'
Usage:
  scripts/e2e-wg-over-transport.sh [--check-only] [--skip-build]

Purpose:
  Runs a reproducible WireGuard-over-vk-turn-proxy-go smoke between WSL and the
  project VPS. The real TURN service is an explicit external dependency.

Required env for a real run:
  Either:
    TURN_LINK=generic-turn://user:pass@turn.example.test:3478
  Or:
    PROVIDER_NAME=vk
    PROVIDER_LINK=https://vk.com/call/join/<invite>

Optional env:
  REMOTE_HOST=vk-turn-proxy-go
  REMOTE_PUBLIC_HOST=176.109.104.105
  LOCAL_SUDO_PASSWORD=...
  PROVIDER_NAME=generic-turn|vk
  PROVIDER_LINK=...
  INTERACTIVE_PROVIDER=true|false
  SKIP_PROVIDER_PREFLIGHT=true|false
  LOCAL_TRANSPORT_PORT=39000
  REMOTE_TRANSPORT_PORT=56040
  LOCAL_WG_PORT=51870
  REMOTE_WG_PORT=51871
  LOCAL_WG_IF=vktpe2ec
  REMOTE_WG_IF=vktpe2es
  LOCAL_WG_ADDR=10.231.0.2/24
  REMOTE_WG_ADDR=10.231.0.1/24
  WG_MTU=1280
  PING_COUNT=3

Examples:
  scripts/e2e-wg-over-transport.sh --check-only
  TURN_LINK='generic-turn://user:pass@turn.example.test:3478' \
    LOCAL_SUDO_PASSWORD='***' \
    scripts/e2e-wg-over-transport.sh
  PROVIDER_NAME='vk' \
    PROVIDER_LINK='https://vk.com/call/join/<invite>' \
    INTERACTIVE_PROVIDER='true' \
    LOCAL_SUDO_PASSWORD='***' \
    scripts/e2e-wg-over-transport.sh
EOF
}

log() {
  printf '[e2e-wg] %s\n' "$*"
}

fail() {
  printf '[e2e-wg] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    fail "required command not found: $1"
  fi
}

run_local_sudo() {
  if [[ -n "${LOCAL_SUDO_PASSWORD}" ]]; then
    printf '%s\n' "${LOCAL_SUDO_PASSWORD}" | sudo -S -p '' -k "$@"
    return
  fi
  sudo "$@"
}

remote_exec() {
  ssh "${REMOTE_HOST}" "$@"
}

resolve_remote_public_host() {
  if [[ -n "${REMOTE_PUBLIC_HOST}" ]]; then
    return
  fi

  REMOTE_PUBLIC_HOST="$(ssh -G "${REMOTE_HOST}" 2>/dev/null | awk '/^hostname / { print $2; exit }')"
  if [[ -z "${REMOTE_PUBLIC_HOST}" ]]; then
    fail "unable to resolve REMOTE_PUBLIC_HOST from ssh config for ${REMOTE_HOST}"
  fi
}

resolve_provider_inputs() {
  if [[ -n "${TURN_LINK}" ]]; then
    if [[ -n "${PROVIDER_NAME}" || -n "${PROVIDER_LINK}" ]]; then
      fail "set either TURN_LINK or PROVIDER_NAME/PROVIDER_LINK, not both"
    fi
    PROVIDER_NAME="generic-turn"
    PROVIDER_LINK="${TURN_LINK}"
  fi

  if [[ -z "${PROVIDER_NAME}" || -z "${PROVIDER_LINK}" ]]; then
    fail "a real run requires TURN_LINK or both PROVIDER_NAME and PROVIDER_LINK"
  fi
}

run_provider_preflight() {
  local -a probe_args=(
    "${DIST_DIR}/probe"
    -provider "${PROVIDER_NAME}"
    -link "${PROVIDER_LINK}"
    -output-dir "${TMP_DIR}/provider-artifacts"
  )

  if [[ "${INTERACTIVE_PROVIDER}" == "true" ]]; then
    probe_args+=(-interactive-provider)
  fi

  log "running provider preflight with ${PROVIDER_NAME}"
  "${probe_args[@]}"
}

assert_local_port_free() {
  local port="$1"
  if ss -lun | awk '{print $5}' | grep -Eq "(^|:)${port}$"; then
    fail "local UDP port ${port} is already in use"
  fi
}

assert_remote_port_free() {
  local port="$1"
  if remote_exec "ss -lun | awk '{print \$5}' | grep -Eq '(^|:)${port}\$'"; then
    fail "remote UDP port ${port} is already in use on ${REMOTE_HOST}"
  fi
}

assert_interface_absent() {
  local iface="$1"
  if ip link show "${iface}" >/dev/null 2>&1; then
    fail "local interface ${iface} already exists"
  fi
}

assert_remote_interface_absent() {
  local iface="$1"
  if remote_exec "ip link show '${iface}' >/dev/null 2>&1"; then
    fail "remote interface ${iface} already exists on ${REMOTE_HOST}"
  fi
}

check_local_wireguard_kernel() {
  run_local_sudo sh -lc "ip link add dev '${LOCAL_WG_IF}' type wireguard && ip link del dev '${LOCAL_WG_IF}'"
}

check_remote_wireguard_kernel() {
  remote_exec "sudo sh -lc \"ip link add dev '${REMOTE_WG_IF}' type wireguard && ip link del dev '${REMOTE_WG_IF}'\""
}

cleanup() {
  local status=$?
  set +e

  if [[ ${status} -ne 0 ]]; then
    if [[ -n "${LOCAL_CLIENT_LOG}" && -f "${LOCAL_CLIENT_LOG}" ]]; then
      log "local tunnel-client log tail:"
      tail -n 40 "${LOCAL_CLIENT_LOG}" >&2 || true
    fi
    if [[ -n "${REMOTE_SERVER_LOG}" ]]; then
      log "remote tunnel-server log tail:"
      remote_exec "tail -n 40 '${REMOTE_SERVER_LOG}'" >&2 || true
    fi
  fi

  if [[ -n "${LOCAL_CLIENT_PID}" ]]; then
    kill "${LOCAL_CLIENT_PID}" >/dev/null 2>&1 || true
    wait "${LOCAL_CLIENT_PID}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${LOCAL_WG_IF}" ]]; then
    run_local_sudo ip link del dev "${LOCAL_WG_IF}" >/dev/null 2>&1 || true
  fi

  if [[ -n "${REMOTE_SERVER_PID}" ]]; then
    remote_exec "kill '${REMOTE_SERVER_PID}' >/dev/null 2>&1 || true" >/dev/null 2>&1 || true
  fi

  if [[ -n "${REMOTE_WG_IF}" ]]; then
    remote_exec "sudo ip link del dev '${REMOTE_WG_IF}' >/dev/null 2>&1 || true" >/dev/null 2>&1 || true
  fi

  if [[ -n "${REMOTE_DIR}" ]]; then
    remote_exec "rm -rf '${REMOTE_DIR}'" >/dev/null 2>&1 || true
  fi

  if [[ -n "${TMP_DIR}" ]]; then
    rm -rf "${TMP_DIR}"
  fi

  exit "${status}"
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only)
      CHECK_ONLY="true"
      shift
      ;;
    --skip-build)
      SKIP_BUILD="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

require_command ssh
require_command scp
require_command ip
require_command ping
require_command wg
require_command sudo
require_command ss

remote_exec "command -v sudo >/dev/null 2>&1" >/dev/null
remote_exec "command -v ip >/dev/null 2>&1" >/dev/null
remote_exec "command -v wg >/dev/null 2>&1" >/dev/null
remote_exec "sudo -n true" >/dev/null

resolve_remote_public_host

assert_local_port_free "${LOCAL_TRANSPORT_PORT}"
assert_local_port_free "${LOCAL_WG_PORT}"
assert_remote_port_free "${REMOTE_TRANSPORT_PORT}"
assert_remote_port_free "${REMOTE_WG_PORT}"
assert_interface_absent "${LOCAL_WG_IF}"
assert_remote_interface_absent "${REMOTE_WG_IF}"

log "checking local WireGuard kernel support"
check_local_wireguard_kernel
log "checking remote WireGuard kernel support"
check_remote_wireguard_kernel

if [[ "${CHECK_ONLY}" == "true" ]]; then
  log "prerequisites look good"
  log "remote_host=${REMOTE_HOST}"
  log "remote_public_host=${REMOTE_PUBLIC_HOST}"
  exit 0
fi

resolve_provider_inputs

require_command go

if [[ "${SKIP_BUILD}" != "true" ]]; then
  log "building linux/amd64 artifacts"
  "${ROOT_DIR}/scripts/build-go-matrix.sh" linux/amd64
fi

[[ -x "${DIST_DIR}/tunnel-client" ]] || fail "missing built artifact: ${DIST_DIR}/tunnel-client"
[[ -x "${DIST_DIR}/tunnel-server" ]] || fail "missing built artifact: ${DIST_DIR}/tunnel-server"
[[ -x "${DIST_DIR}/probe" ]] || fail "missing built artifact: ${DIST_DIR}/probe"

TMP_DIR="$(mktemp -d)"
LOCAL_CLIENT_LOG="${TMP_DIR}/tunnel-client.log"

SERVER_PRIVATE_KEY_FILE="${TMP_DIR}/server.key"
CLIENT_PRIVATE_KEY_FILE="${TMP_DIR}/client.key"

wg genkey | tee "${SERVER_PRIVATE_KEY_FILE}" | wg pubkey > "${TMP_DIR}/server.pub"
wg genkey | tee "${CLIENT_PRIVATE_KEY_FILE}" | wg pubkey > "${TMP_DIR}/client.pub"

SERVER_PUBLIC_KEY="$(tr -d '\n' < "${TMP_DIR}/server.pub")"
CLIENT_PUBLIC_KEY="$(tr -d '\n' < "${TMP_DIR}/client.pub")"

chmod 600 "${SERVER_PRIVATE_KEY_FILE}" "${CLIENT_PRIVATE_KEY_FILE}"

if [[ "${SKIP_PROVIDER_PREFLIGHT}" != "true" ]]; then
  run_provider_preflight
fi

if [[ "${INTERACTIVE_PROVIDER}" == "true" ]]; then
  fail "interactive provider flows are not yet supported by this unattended end-to-end script after preflight; use a provider input that resolves non-interactively or provide direct TURN credentials"
fi

REMOTE_DIR="$(remote_exec "mktemp -d \"\${HOME}/vktp-e2e.${RUN_ID}.XXXXXX\"")"
REMOTE_SERVER_LOG="${REMOTE_DIR}/tunnel-server.log"

log "copying tunnel-server and server key to ${REMOTE_HOST}:${REMOTE_DIR}"
scp "${DIST_DIR}/tunnel-server" "${REMOTE_HOST}:${REMOTE_DIR}/tunnel-server" >/dev/null
scp "${SERVER_PRIVATE_KEY_FILE}" "${REMOTE_HOST}:${REMOTE_DIR}/server.key" >/dev/null

remote_exec "chmod 700 '${REMOTE_DIR}/tunnel-server' && chmod 600 '${REMOTE_DIR}/server.key'"

log "configuring remote WireGuard interface ${REMOTE_WG_IF}"
remote_exec "sudo sh -lc '
ip link add dev \"${REMOTE_WG_IF}\" type wireguard
ip address add \"${REMOTE_WG_ADDR}\" dev \"${REMOTE_WG_IF}\"
ip link set mtu \"${WG_MTU}\" dev \"${REMOTE_WG_IF}\"
wg set \"${REMOTE_WG_IF}\" \
  private-key \"${REMOTE_DIR}/server.key\" \
  listen-port \"${REMOTE_WG_PORT}\" \
  peer \"${CLIENT_PUBLIC_KEY}\" \
  allowed-ips \"${REMOTE_ALLOWED_IP}\"
ip link set up dev \"${REMOTE_WG_IF}\"
'"

log "starting remote tunnel-server on ${REMOTE_PUBLIC_HOST}:${REMOTE_TRANSPORT_PORT}"
remote_exec "sh -lc '
nohup \"${REMOTE_DIR}/tunnel-server\" \
  -listen \"0.0.0.0:${REMOTE_TRANSPORT_PORT}\" \
  -egress udp \
  -connect \"127.0.0.1:${REMOTE_WG_PORT}\" \
  >\"${REMOTE_SERVER_LOG}\" 2>&1 &
echo \$! >\"${REMOTE_DIR}/tunnel-server.pid\"
'"
REMOTE_SERVER_PID="$(remote_exec "cat '${REMOTE_DIR}/tunnel-server.pid'")"

log "configuring local WireGuard interface ${LOCAL_WG_IF}"
run_local_sudo ip link add dev "${LOCAL_WG_IF}" type wireguard
run_local_sudo ip address add "${LOCAL_WG_ADDR}" dev "${LOCAL_WG_IF}"
run_local_sudo ip link set mtu "${WG_MTU}" dev "${LOCAL_WG_IF}"
run_local_sudo wg set "${LOCAL_WG_IF}" \
  private-key "${CLIENT_PRIVATE_KEY_FILE}" \
  listen-port "${LOCAL_WG_PORT}" \
  peer "${SERVER_PUBLIC_KEY}" \
  endpoint "${LOCAL_TRANSPORT_HOST}:${LOCAL_TRANSPORT_PORT}" \
  allowed-ips "${LOCAL_ALLOWED_IP}" \
  persistent-keepalive 5
run_local_sudo ip link set up dev "${LOCAL_WG_IF}"

log "starting local tunnel-client on ${LOCAL_TRANSPORT_HOST}:${LOCAL_TRANSPORT_PORT}"
"${DIST_DIR}/tunnel-client" \
  -provider "${PROVIDER_NAME}" \
  -link "${PROVIDER_LINK}" \
  -listen "${LOCAL_TRANSPORT_HOST}:${LOCAL_TRANSPORT_PORT}" \
  -peer "${REMOTE_PUBLIC_HOST}:${REMOTE_TRANSPORT_PORT}" \
  -ingress udp \
  -mode udp \
  -dtls=true \
  -connections 1 \
  >"${LOCAL_CLIENT_LOG}" 2>&1 &
LOCAL_CLIENT_PID="$!"

for _ in $(seq 1 30); do
  if ! kill -0 "${LOCAL_CLIENT_PID}" >/dev/null 2>&1; then
    wait "${LOCAL_CLIENT_PID}" || true
    fail "local tunnel-client exited before readiness"
  fi
  if grep -Eq 'event=runtime_ready|supervised session ready|client transport connected' "${LOCAL_CLIENT_LOG}"; then
    break
  fi
  sleep 1
done

if ! grep -Eq 'event=runtime_ready|supervised session ready|client transport connected' "${LOCAL_CLIENT_LOG}"; then
  fail "local tunnel-client did not reach runtime readiness on ${LOCAL_TRANSPORT_HOST}:${LOCAL_TRANSPORT_PORT}"
fi

sleep 2

REMOTE_WG_IP="${REMOTE_WG_ADDR%/*}"
log "running ping smoke over WireGuard to ${REMOTE_WG_IP}"
run_local_sudo ping -I "${LOCAL_WG_IF}" -c "${PING_COUNT}" -W 2 "${REMOTE_WG_IP}"

log "WireGuard transfer counters (local)"
run_local_sudo wg show "${LOCAL_WG_IF}"
log "WireGuard transfer counters (remote)"
remote_exec "sudo wg show '${REMOTE_WG_IF}'"

log "end-to-end smoke passed"
