#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${ROOT_DIR}/dist/go/linux-amd64"
ARTIFACT_ROOT="${ARTIFACT_ROOT:-${ROOT_DIR}/artifacts/wg-live-vk}"

REMOTE_HOST="${REMOTE_HOST:-vk-turn-proxy-go}"
REMOTE_PUBLIC_HOST="${REMOTE_PUBLIC_HOST:-}"
PROVIDER_LINK="${PROVIDER_LINK:-}"
LOCAL_SUDO_PASSWORD="${LOCAL_SUDO_PASSWORD:-}"

CLIENTD_HOST="${CLIENTD_HOST:-127.0.0.1}"
CLIENTD_PORT="${CLIENTD_PORT:-37777}"
CLIENTD_LISTEN="${CLIENTD_HOST}:${CLIENTD_PORT}"

LOCAL_TRANSPORT_HOST="${LOCAL_TRANSPORT_HOST:-127.0.0.1}"
LOCAL_TRANSPORT_PORT="${LOCAL_TRANSPORT_PORT:-39000}"
REMOTE_TRANSPORT_PORT="${REMOTE_TRANSPORT_PORT:-56040}"
REMOTE_WG_PORT="${REMOTE_WG_PORT:-51871}"
LOCAL_WG_PORT="${LOCAL_WG_PORT:-51870}"

LOCAL_WG_IF="${LOCAL_WG_IF:-vktplivec}"
REMOTE_WG_IF="${REMOTE_WG_IF:-vktplives}"
LOCAL_WG_ADDR="${LOCAL_WG_ADDR:-10.231.1.2/24}"
REMOTE_WG_ADDR="${REMOTE_WG_ADDR:-10.231.1.1/24}"
LOCAL_ALLOWED_IP="${LOCAL_ALLOWED_IP:-10.231.1.1/32}"
REMOTE_ALLOWED_IP="${REMOTE_ALLOWED_IP:-10.231.1.2/32}"
WG_MTU="${WG_MTU:-1280}"
WG_PERSISTENT_KEEPALIVE="${WG_PERSISTENT_KEEPALIVE:-15}"
PING_TARGET="${PING_TARGET:-10.231.1.1}"
PING_COUNT="${PING_COUNT:-3}"

SESSION_WAIT_SECONDS="${SESSION_WAIT_SECONDS:-90}"
READY_WAIT_SECONDS="${READY_WAIT_SECONDS:-120}"
POLL_INTERVAL_SECONDS="${POLL_INTERVAL_SECONDS:-1}"
LOG_LEVEL="${LOG_LEVEL:-info}"

STATE_DIR="${STATE_DIR:-}"
STATE_FILE=""

COMMAND="${1:-}"
SKIP_BUILD="false"

RUN_ID=""
CLIENTD_PID=""
SESSION_ID=""
CHALLENGE_ID=""
CHALLENGE_URL=""
CHALLENGE_PROMPT=""
REMOTE_DIR=""
REMOTE_SERVER_PID=""
REMOTE_SERVER_LOG=""

usage() {
  cat <<'EOF'
Usage:
  scripts/e2e-wg-live-vk.sh check [--skip-build]
  scripts/e2e-wg-live-vk.sh run [--skip-build]
  scripts/e2e-wg-live-vk.sh start [--skip-build]
  scripts/e2e-wg-live-vk.sh continue
  scripts/e2e-wg-live-vk.sh cleanup

Purpose:
  Runs the repo-owned two-step live VK workflow for WireGuard over the current
  udp->udp transport path without repeating provider resolution.

Required env:
  PROVIDER_LINK=https://vk.com/call/join/<invite>   (for start)
  LOCAL_SUDO_PASSWORD=...                           (when local sudo prompts)

Optional env:
  STATE_DIR=/abs/path/to/existing-or-new-run-state
  REMOTE_HOST=vk-turn-proxy-go
  REMOTE_PUBLIC_HOST=176.109.104.105
  CLIENTD_PORT=37777
  LOCAL_TRANSPORT_PORT=39000
  REMOTE_TRANSPORT_PORT=56040
  LOCAL_WG_PORT=51870
  REMOTE_WG_PORT=51871
  LOG_LEVEL=debug
  VK_PROVIDER_BROWSER=/path/to/chromium
  VK_PROVIDER_BROWSER_HEADLESS=false

Examples:
  PROVIDER_LINK='https://vk.com/call/join/<invite>' \
    LOCAL_SUDO_PASSWORD='***' \
    scripts/e2e-wg-live-vk.sh run

  PROVIDER_LINK='https://vk.com/call/join/<invite>' \
    LOCAL_SUDO_PASSWORD='***' \
    scripts/e2e-wg-live-vk.sh start

  LOCAL_SUDO_PASSWORD='***' \
    STATE_DIR='/home/user/repo/artifacts/wg-live-vk/run-...' \
    scripts/e2e-wg-live-vk.sh continue

  STATE_DIR='/home/user/repo/artifacts/wg-live-vk/run-...' \
    scripts/e2e-wg-live-vk.sh cleanup
EOF
}

log() {
  printf '[wg-live-vk] %s\n' "$*"
}

fail() {
  printf '[wg-live-vk] ERROR: %s\n' "$*" >&2
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

assert_browser_available() {
  if [[ -n "${VK_PROVIDER_BROWSER:-}" ]]; then
    [[ -x "${VK_PROVIDER_BROWSER}" ]] || fail "VK_PROVIDER_BROWSER is not executable: ${VK_PROVIDER_BROWSER}"
    return
  fi

  for candidate in chromium chromium-browser google-chrome google-chrome-stable; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      return
    fi
  done
  fail "no supported browser executable found; install chromium or set VK_PROVIDER_BROWSER"
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

state_file_path() {
  printf '%s/state.env\n' "${STATE_DIR}"
}

write_state() {
  mkdir -p "${STATE_DIR}"
  STATE_FILE="$(state_file_path)"
  {
    printf 'RUN_ID=%q\n' "${RUN_ID}"
    printf 'STATE_DIR=%q\n' "${STATE_DIR}"
    printf 'REMOTE_HOST=%q\n' "${REMOTE_HOST}"
    printf 'REMOTE_PUBLIC_HOST=%q\n' "${REMOTE_PUBLIC_HOST}"
    printf 'PROVIDER_LINK=%q\n' "${PROVIDER_LINK}"
    printf 'CLIENTD_HOST=%q\n' "${CLIENTD_HOST}"
    printf 'CLIENTD_PORT=%q\n' "${CLIENTD_PORT}"
    printf 'CLIENTD_LISTEN=%q\n' "${CLIENTD_LISTEN}"
    printf 'LOCAL_TRANSPORT_HOST=%q\n' "${LOCAL_TRANSPORT_HOST}"
    printf 'LOCAL_TRANSPORT_PORT=%q\n' "${LOCAL_TRANSPORT_PORT}"
    printf 'REMOTE_TRANSPORT_PORT=%q\n' "${REMOTE_TRANSPORT_PORT}"
    printf 'LOCAL_WG_PORT=%q\n' "${LOCAL_WG_PORT}"
    printf 'REMOTE_WG_PORT=%q\n' "${REMOTE_WG_PORT}"
    printf 'LOCAL_WG_IF=%q\n' "${LOCAL_WG_IF}"
    printf 'REMOTE_WG_IF=%q\n' "${REMOTE_WG_IF}"
    printf 'LOCAL_WG_ADDR=%q\n' "${LOCAL_WG_ADDR}"
    printf 'REMOTE_WG_ADDR=%q\n' "${REMOTE_WG_ADDR}"
    printf 'LOCAL_ALLOWED_IP=%q\n' "${LOCAL_ALLOWED_IP}"
    printf 'REMOTE_ALLOWED_IP=%q\n' "${REMOTE_ALLOWED_IP}"
    printf 'WG_MTU=%q\n' "${WG_MTU}"
    printf 'WG_PERSISTENT_KEEPALIVE=%q\n' "${WG_PERSISTENT_KEEPALIVE}"
    printf 'PING_TARGET=%q\n' "${PING_TARGET}"
    printf 'PING_COUNT=%q\n' "${PING_COUNT}"
    printf 'SESSION_WAIT_SECONDS=%q\n' "${SESSION_WAIT_SECONDS}"
    printf 'READY_WAIT_SECONDS=%q\n' "${READY_WAIT_SECONDS}"
    printf 'POLL_INTERVAL_SECONDS=%q\n' "${POLL_INTERVAL_SECONDS}"
    printf 'LOG_LEVEL=%q\n' "${LOG_LEVEL}"
    printf 'CLIENTD_PID=%q\n' "${CLIENTD_PID}"
    printf 'SESSION_ID=%q\n' "${SESSION_ID}"
    printf 'CHALLENGE_ID=%q\n' "${CHALLENGE_ID}"
    printf 'CHALLENGE_URL=%q\n' "${CHALLENGE_URL}"
    printf 'CHALLENGE_PROMPT=%q\n' "${CHALLENGE_PROMPT}"
    printf 'REMOTE_DIR=%q\n' "${REMOTE_DIR}"
    printf 'REMOTE_SERVER_PID=%q\n' "${REMOTE_SERVER_PID}"
    printf 'REMOTE_SERVER_LOG=%q\n' "${REMOTE_SERVER_LOG}"
  } > "${STATE_FILE}"
}

load_state() {
  [[ -n "${STATE_DIR}" ]] || fail "STATE_DIR is required for ${COMMAND}"
  STATE_FILE="$(state_file_path)"
  [[ -f "${STATE_FILE}" ]] || fail "state file not found: ${STATE_FILE}"
  # shellcheck disable=SC1090
  source "${STATE_FILE}"
  STATE_FILE="$(state_file_path)"
}

json_get() {
  local file="$1"
  local query="$2"
  jq -r "${query}" "${file}"
}

clientd_url() {
  printf 'http://%s' "${CLIENTD_LISTEN}"
}

session_json_path() {
  printf '%s/session.json' "${STATE_DIR}"
}

challenge_json_path() {
  printf '%s/challenge.json' "${STATE_DIR}"
}

diagnostics_json_path() {
  printf '%s/diagnostics.json' "${STATE_DIR}"
}

clientd_log_path() {
  printf '%s/clientd.log' "${STATE_DIR}"
}

local_wg_show_path() {
  printf '%s/local-wg-show.txt' "${STATE_DIR}"
}

remote_wg_show_path() {
  printf '%s/remote-wg-show.txt' "${STATE_DIR}"
}

http_request() {
  local method="$1"
  local url="$2"
  local body="${3:-}"
  local response_file
  local status

  response_file="$(mktemp)"
  if [[ -n "${body}" ]]; then
    status="$(curl -sS -o "${response_file}" -w '%{http_code}' -X "${method}" -H 'Content-Type: application/json' --data "${body}" "${url}")" || {
      cat "${response_file}" >&2
      rm -f "${response_file}"
      return 1
    }
  else
    status="$(curl -sS -o "${response_file}" -w '%{http_code}' -X "${method}" "${url}")" || {
      cat "${response_file}" >&2
      rm -f "${response_file}"
      return 1
    }
  fi

  if [[ "${status}" -lt 200 || "${status}" -ge 300 ]]; then
    log "http ${method} ${url} failed with status=${status}"
    cat "${response_file}" >&2
    rm -f "${response_file}"
    return 1
  fi

  cat "${response_file}"
  rm -f "${response_file}"
}

wait_for_clientd() {
  local deadline
  deadline=$((SECONDS + 15))
  while (( SECONDS < deadline )); do
    if curl -sS "$(clientd_url)/v1/host" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  fail "clientd did not become ready on ${CLIENTD_LISTEN}"
}

assert_local_tcp_port_free() {
  local port="$1"
  if ss -ltn | awk '{print $4}' | grep -Eq "(^|:)${port}$"; then
    fail "local TCP port ${port} is already in use"
  fi
}

assert_local_udp_port_free() {
  local port="$1"
  if ss -lun | awk '{print $5}' | grep -Eq "(^|:)${port}$"; then
    fail "local UDP port ${port} is already in use"
  fi
}

assert_remote_udp_port_free() {
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

fresh_run_preflight() {
  require_command ssh
  require_command scp
  require_command ip
  require_command ping
  require_command wg
  require_command sudo
  require_command ss
  require_command jq
  require_command curl

  remote_exec "command -v sudo >/dev/null 2>&1" >/dev/null
  remote_exec "command -v ip >/dev/null 2>&1" >/dev/null
  remote_exec "command -v wg >/dev/null 2>&1" >/dev/null
  remote_exec "command -v ss >/dev/null 2>&1" >/dev/null
  remote_exec "sudo -n true" >/dev/null

  resolve_remote_public_host
  assert_browser_available

  assert_local_tcp_port_free "${CLIENTD_PORT}"
  assert_local_udp_port_free "${LOCAL_TRANSPORT_PORT}"
  assert_local_udp_port_free "${LOCAL_WG_PORT}"
  assert_remote_udp_port_free "${REMOTE_TRANSPORT_PORT}"
  assert_remote_udp_port_free "${REMOTE_WG_PORT}"
  assert_interface_absent "${LOCAL_WG_IF}"
  assert_remote_interface_absent "${REMOTE_WG_IF}"

  log "checking local WireGuard kernel support"
  check_local_wireguard_kernel
  log "checking remote WireGuard kernel support"
  check_remote_wireguard_kernel
}

continue_preflight() {
  require_command ssh
  require_command scp
  require_command ip
  require_command ping
  require_command wg
  require_command sudo
  require_command ss
  require_command jq
  require_command curl

  remote_exec "command -v sudo >/dev/null 2>&1" >/dev/null
  remote_exec "command -v ip >/dev/null 2>&1" >/dev/null
  remote_exec "command -v wg >/dev/null 2>&1" >/dev/null
  remote_exec "command -v ss >/dev/null 2>&1" >/dev/null
  remote_exec "sudo -n true" >/dev/null

  assert_local_udp_port_free "${LOCAL_TRANSPORT_PORT}"
  assert_local_udp_port_free "${LOCAL_WG_PORT}"
  assert_remote_udp_port_free "${REMOTE_TRANSPORT_PORT}"
  assert_remote_udp_port_free "${REMOTE_WG_PORT}"
  assert_interface_absent "${LOCAL_WG_IF}"
  assert_remote_interface_absent "${REMOTE_WG_IF}"

  log "re-checking local WireGuard kernel support"
  check_local_wireguard_kernel
  log "re-checking remote WireGuard kernel support"
  check_remote_wireguard_kernel
}

build_artifacts() {
  if [[ "${SKIP_BUILD}" != "true" ]]; then
    require_command go
    log "building linux/amd64 artifacts"
    "${ROOT_DIR}/scripts/build-go-matrix.sh" linux/amd64
  fi
  [[ -x "${DIST_DIR}/clientd" ]] || fail "missing built artifact: ${DIST_DIR}/clientd"
  [[ -x "${DIST_DIR}/tunnel-server" ]] || fail "missing built artifact: ${DIST_DIR}/tunnel-server"
}

start_clientd() {
  local log_file
  log_file="$(clientd_log_path)"
  nohup "${DIST_DIR}/clientd" -listen "${CLIENTD_LISTEN}" -log-level "${LOG_LEVEL}" >"${log_file}" 2>&1 &
  CLIENTD_PID="$!"
  write_state
  wait_for_clientd
}

generate_wg_keys() {
  wg genkey | tee "${STATE_DIR}/server.key" | wg pubkey > "${STATE_DIR}/server.pub"
  wg genkey | tee "${STATE_DIR}/client.key" | wg pubkey > "${STATE_DIR}/client.pub"
  chmod 600 "${STATE_DIR}/server.key" "${STATE_DIR}/client.key"
}

start_session() {
  local session_request
  local session_response

  session_request="$(
    jq -n \
      --arg provider "vk" \
      --arg link "${PROVIDER_LINK}" \
      --arg listen "${LOCAL_TRANSPORT_HOST}:${LOCAL_TRANSPORT_PORT}" \
      --arg peer "${REMOTE_PUBLIC_HOST}:${REMOTE_TRANSPORT_PORT}" \
      --arg logLevel "${LOG_LEVEL}" \
      '{
        spec: {
          provider: $provider,
          link: $link,
          listen_addr: $listen,
          peer_addr: $peer,
          ingress: "udp",
          connections: 1,
          mode: "udp",
          use_dtls: true,
          interactive_provider: true,
          log_level: $logLevel
        }
      }'
  )"

  session_response="$(http_request POST "$(clientd_url)/v1/sessions" "${session_request}")"
  printf '%s\n' "${session_response}" > "$(session_json_path)"
  SESSION_ID="$(jq -r '.id // empty' "$(session_json_path)")"
  [[ -n "${SESSION_ID}" ]] || fail "clientd session response did not include id"
  write_state
}

fetch_session() {
  http_request GET "$(clientd_url)/v1/sessions/${SESSION_ID}" > "$(session_json_path)"
}

fetch_challenge() {
  http_request GET "$(clientd_url)/v1/challenges/${CHALLENGE_ID}" > "$(challenge_json_path)"
}

fetch_diagnostics() {
  if [[ -n "${SESSION_ID}" ]]; then
    http_request GET "$(clientd_url)/v1/sessions/${SESSION_ID}/diagnostics" > "$(diagnostics_json_path)"
  fi
}

wait_for_state() {
  local expected="$1"
  local timeout_seconds="$2"
  local deadline
  local state

  deadline=$((SECONDS + timeout_seconds))
  while (( SECONDS < deadline )); do
    fetch_session
    state="$(json_get "$(session_json_path)" '.state // empty')"
    case "${state}" in
      "${expected}")
        return 0
        ;;
      ready)
        fail "session reached ready before challenge; this invite no longer needs the two-step interactive workflow"
        ;;
      stopped)
        fetch_diagnostics || true
        fail "session stopped before reaching ${expected}; inspect $(diagnostics_json_path)"
        ;;
      failed)
        fetch_diagnostics || true
        fail "session entered failed state; inspect $(diagnostics_json_path)"
        ;;
    esac
    sleep "${POLL_INTERVAL_SECONDS}"
  done
  fail "timed out waiting for session state=${expected}"
}

wait_for_ready_or_fail() {
  local deadline
  local state

  deadline=$((SECONDS + READY_WAIT_SECONDS))
  while (( SECONDS < deadline )); do
    fetch_session
    state="$(json_get "$(session_json_path)" '.state // empty')"
    case "${state}" in
      ready)
        return 0
        ;;
      failed|stopped)
        fetch_diagnostics || true
        fail "session ended with state=${state}; inspect $(diagnostics_json_path)"
        ;;
    esac
    sleep "${POLL_INTERVAL_SECONDS}"
  done
  fail "timed out waiting for session readiness"
}

verify_clientd_pid() {
  [[ -n "${CLIENTD_PID}" ]] || fail "clientd pid missing from state"
  if ! kill -0 "${CLIENTD_PID}" >/dev/null 2>&1; then
    fail "clientd process is not running; inspect $(clientd_log_path)"
  fi
}

save_challenge_from_session() {
  CHALLENGE_ID="$(json_get "$(session_json_path)" '.active_challenge_id // empty')"
  [[ -n "${CHALLENGE_ID}" ]] || fail "session reached challenge_required without active_challenge_id"
  fetch_challenge
  CHALLENGE_URL="$(json_get "$(challenge_json_path)" '.open_url // empty')"
  CHALLENGE_PROMPT="$(json_get "$(challenge_json_path)" '.prompt // empty')"
  write_state
}

start_remote_server() {
  REMOTE_DIR="$(remote_exec "mktemp -d \"\${HOME}/vktp-live-vk.${RUN_ID}.XXXXXX\"")"
  REMOTE_SERVER_LOG="${REMOTE_DIR}/tunnel-server.log"
  write_state

  log "copying tunnel-server and server key to ${REMOTE_HOST}:${REMOTE_DIR}"
  scp "${DIST_DIR}/tunnel-server" "${REMOTE_HOST}:${REMOTE_DIR}/tunnel-server" >/dev/null
  scp "${STATE_DIR}/server.key" "${REMOTE_HOST}:${REMOTE_DIR}/server.key" >/dev/null

  remote_exec "chmod 700 '${REMOTE_DIR}/tunnel-server' && chmod 600 '${REMOTE_DIR}/server.key'"

  log "configuring remote WireGuard interface ${REMOTE_WG_IF}"
  remote_exec "sudo sh -lc '
ip link add dev \"${REMOTE_WG_IF}\" type wireguard
ip address add \"${REMOTE_WG_ADDR}\" dev \"${REMOTE_WG_IF}\"
ip link set mtu \"${WG_MTU}\" dev \"${REMOTE_WG_IF}\"
wg set \"${REMOTE_WG_IF}\" \
  private-key \"${REMOTE_DIR}/server.key\" \
  listen-port \"${REMOTE_WG_PORT}\" \
  peer \"$(tr -d '\n' < "${STATE_DIR}/client.pub")\" \
  allowed-ips \"${REMOTE_ALLOWED_IP}\"
ip link set up dev \"${REMOTE_WG_IF}\"
'"

  log "starting remote tunnel-server on ${REMOTE_PUBLIC_HOST}:${REMOTE_TRANSPORT_PORT}"
  remote_exec "sh -lc '
nohup \"${REMOTE_DIR}/tunnel-server\" \
  -listen \"0.0.0.0:${REMOTE_TRANSPORT_PORT}\" \
  -egress udp \
  -connect \"127.0.0.1:${REMOTE_WG_PORT}\" \
  -log-level \"${LOG_LEVEL}\" \
  >\"${REMOTE_SERVER_LOG}\" 2>&1 &
echo \$! >\"${REMOTE_DIR}/tunnel-server.pid\"
'"
  REMOTE_SERVER_PID="$(remote_exec "cat '${REMOTE_DIR}/tunnel-server.pid'")"
  write_state
}

start_local_wireguard() {
  log "configuring local WireGuard interface ${LOCAL_WG_IF}"
  run_local_sudo sh -lc "
ip link add dev '${LOCAL_WG_IF}' type wireguard
ip address add '${LOCAL_WG_ADDR}' dev '${LOCAL_WG_IF}'
ip link set mtu '${WG_MTU}' dev '${LOCAL_WG_IF}'
wg set '${LOCAL_WG_IF}' \
  private-key '${STATE_DIR}/client.key' \
  listen-port '${LOCAL_WG_PORT}' \
  peer '$(tr -d '\n' < "${STATE_DIR}/server.pub")' \
  allowed-ips '${LOCAL_ALLOWED_IP}' \
  endpoint '${LOCAL_TRANSPORT_HOST}:${LOCAL_TRANSPORT_PORT}' \
  persistent-keepalive '${WG_PERSISTENT_KEEPALIVE}'
ip link set up dev '${LOCAL_WG_IF}'
"
}

continue_challenge() {
  local response
  response="$(http_request POST "$(clientd_url)/v1/challenges/${CHALLENGE_ID}/continue")"
  printf '%s\n' "${response}" > "${STATE_DIR}/challenge-continue-response.json"
}

ping_over_wireguard() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if ping -I "${LOCAL_WG_IF}" -c "${PING_COUNT}" -W 2 "${PING_TARGET}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  fail "WireGuard ping to ${PING_TARGET} did not succeed"
}

capture_wg_show() {
  run_local_sudo wg show "${LOCAL_WG_IF}" > "$(local_wg_show_path)"
  remote_exec "sudo wg show '${REMOTE_WG_IF}'" > "$(remote_wg_show_path)"
}

stop_session_if_possible() {
  if [[ -z "${SESSION_ID}" ]]; then
    return
  fi
  if curl -sS "$(clientd_url)/v1/host" >/dev/null 2>&1; then
    http_request POST "$(clientd_url)/v1/sessions/${SESSION_ID}/stop" >/dev/null || true
  fi
}

stop_clientd_if_possible() {
  if [[ -n "${CLIENTD_PID}" ]]; then
    kill "${CLIENTD_PID}" >/dev/null 2>&1 || true
    wait "${CLIENTD_PID}" >/dev/null 2>&1 || true
    CLIENTD_PID=""
  fi
}

cleanup_local_wireguard() {
  if ip link show "${LOCAL_WG_IF}" >/dev/null 2>&1; then
    run_local_sudo ip link del dev "${LOCAL_WG_IF}" >/dev/null 2>&1 || true
  fi
}

cleanup_remote_wireguard() {
  if remote_exec "ip link show '${REMOTE_WG_IF}' >/dev/null 2>&1"; then
    remote_exec "sudo ip link del dev '${REMOTE_WG_IF}' >/dev/null 2>&1 || true" >/dev/null 2>&1 || true
  fi
}

cleanup_remote_server() {
  if [[ -n "${REMOTE_SERVER_PID}" ]]; then
    remote_exec "kill '${REMOTE_SERVER_PID}' >/dev/null 2>&1 || true" >/dev/null 2>&1 || true
    REMOTE_SERVER_PID=""
  fi
  if [[ -n "${REMOTE_DIR}" ]]; then
    remote_exec "rm -rf '${REMOTE_DIR}'" >/dev/null 2>&1 || true
    REMOTE_DIR=""
    REMOTE_SERVER_LOG=""
  fi
}

print_start_success() {
  log "session is waiting on live VK challenge"
  log "state_dir=${STATE_DIR}"
  log "session_id=${SESSION_ID}"
  log "challenge_id=${CHALLENGE_ID}"
  if [[ -n "${CHALLENGE_URL}" ]]; then
    log "challenge_url=${CHALLENGE_URL}"
  fi
  if [[ -n "${CHALLENGE_PROMPT}" ]]; then
    log "challenge_prompt=${CHALLENGE_PROMPT}"
  fi
  log "next: STATE_DIR='${STATE_DIR}' LOCAL_SUDO_PASSWORD='***' ./scripts/e2e-wg-live-vk.sh continue"
}

print_continue_success() {
  log "WireGuard over transport reached ready"
  log "state_dir=${STATE_DIR}"
  log "diagnostics=$(diagnostics_json_path)"
  log "local_wg_show=$(local_wg_show_path)"
  log "remote_wg_show=$(remote_wg_show_path)"
  log "cleanup: STATE_DIR='${STATE_DIR}' LOCAL_SUDO_PASSWORD='***' ./scripts/e2e-wg-live-vk.sh cleanup"
}

wait_for_operator_continue() {
  local input

  [[ -t 0 ]] || fail "interactive run requires a TTY on stdin; use start/continue if you need a paused workflow"

  log "the controlled browser should already be open for the VK challenge"
  if [[ -n "${CHALLENGE_URL}" ]]; then
    log "browser challenge url=${CHALLENGE_URL}"
  fi
  if [[ -n "${CHALLENGE_PROMPT}" ]]; then
    log "browser prompt=${CHALLENGE_PROMPT}"
  fi
  log "complete the captcha and any VK login/join steps in that browser"

  while true; do
    printf '[wg-live-vk] type "continue" to proceed with the same session, or "abort" to stop: '
    IFS= read -r input
    case "${input}" in
      continue|CONTINUE|Continue)
        return 0
        ;;
      abort|ABORT|Abort)
        cleanup_command
        fail "interactive run aborted by operator"
        ;;
      *)
        log "unrecognized input: ${input}"
        ;;
    esac
  done
}

check_command() {
  fresh_run_preflight
  if [[ "${SKIP_BUILD}" != "true" ]]; then
    build_artifacts
  fi
  log "prerequisites look good"
  log "remote_host=${REMOTE_HOST}"
  log "remote_public_host=${REMOTE_PUBLIC_HOST}"
}

start_command() {
  [[ -n "${PROVIDER_LINK}" ]] || fail "PROVIDER_LINK is required for start"
  fresh_run_preflight
  build_artifacts

  if [[ -n "${STATE_DIR}" ]]; then
    [[ ! -e "${STATE_DIR}" ]] || fail "STATE_DIR already exists: ${STATE_DIR}"
    mkdir -p "$(dirname "${STATE_DIR}")"
    mkdir -p "${STATE_DIR}"
  else
    mkdir -p "${ARTIFACT_ROOT}"
    RUN_ID="$(date -u +%Y%m%dT%H%M%SZ)-$$"
    STATE_DIR="$(mktemp -d "${ARTIFACT_ROOT}/vk-live.${RUN_ID}.XXXXXX")"
  fi
  RUN_ID="${RUN_ID:-$(basename "${STATE_DIR}")}"
  STATE_FILE="$(state_file_path)"
  write_state

  generate_wg_keys
  start_clientd
  log "starting interactive VK session through clientd on ${CLIENTD_LISTEN}"
  start_session
  wait_for_state "challenge_required" "${SESSION_WAIT_SECONDS}"
  save_challenge_from_session
  fetch_diagnostics || true
  print_start_success
}

run_command() {
  start_command
  wait_for_operator_continue
  continue_command
}

continue_command() {
  load_state
  verify_clientd_pid
  continue_preflight
  build_artifacts

  fetch_session
  if [[ "$(json_get "$(session_json_path)" '.state // empty')" != "challenge_required" ]]; then
    fail "session is not in challenge_required; inspect $(session_json_path)"
  fi
  if [[ "$(json_get "$(session_json_path)" '.active_challenge_id // empty')" != "${CHALLENGE_ID}" ]]; then
    fail "session active_challenge_id no longer matches state file"
  fi

  fetch_challenge
  if [[ "$(json_get "$(challenge_json_path)" '.status // empty')" != "pending" ]]; then
    fail "challenge status is not pending; inspect $(challenge_json_path)"
  fi

  start_remote_server
  start_local_wireguard
  continue_challenge
  wait_for_ready_or_fail
  fetch_diagnostics || true
  ping_over_wireguard
  capture_wg_show
  print_continue_success
}

cleanup_command() {
  load_state
  stop_session_if_possible
  stop_clientd_if_possible
  cleanup_local_wireguard
  cleanup_remote_server
  cleanup_remote_wireguard
  write_state
  log "cleanup completed; state remains in ${STATE_DIR}"
}

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
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

case "${COMMAND}" in
  check)
    check_command
    ;;
  run)
    run_command
    ;;
  start)
    start_command
    ;;
  continue)
    continue_command
    ;;
  cleanup)
    cleanup_command
    ;;
  ""|-h|--help)
    usage
    exit 0
    ;;
  *)
    fail "unknown command: ${COMMAND}"
    ;;
esac
