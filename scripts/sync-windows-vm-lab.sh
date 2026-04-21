#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

VM_HOST="${VM_HOST:-192.168.32.142}"
VM_USER="${VM_USER:-codex}"
VM_SSH_KEY="${VM_SSH_KEY:-$HOME/.ssh/codex-vmware-win10}"
VM_LAB_ROOT="${VM_LAB_ROOT:-C:\\Users\\codex\\vk-turn-lab}"
VM_HOME_DIR="${VM_HOME_DIR:-${VM_LAB_ROOT%\\vk-turn-lab}}"
VM_PROFILE_DEST="${VM_PROFILE_DEST:-${VM_HOME_DIR}\\.local\\state\\vk-turn-proxy-go\\wg\\desktop1-windows.conf}"
LOCAL_WIREGUARD_PROFILE="${LOCAL_WIREGUARD_PROFILE:-$HOME/.local/state/vk-turn-proxy-go/wg/desktop1-windows.conf}"

SSH_OPTS=(
  -i "${VM_SSH_KEY}"
  -o StrictHostKeyChecking=no
)

log() {
  echo "==> $1"
}

require_file() {
  local path="$1"
  if [[ ! -f "${path}" ]]; then
    echo "required file not found: ${path}" >&2
    exit 1
  fi
}

require_file "${VM_SSH_KEY}"
require_file "${ROOT_DIR}/dist/windows-gui/clientd.exe"
require_file "${ROOT_DIR}/dist/windows-gui/RelayDock.exe"
require_file "${ROOT_DIR}/dist/windows-gui/wintun.dll"

log "pack current Windows bundle"
tar -C "${ROOT_DIR}/dist" -czf "${TMP_DIR}/windows-gui-bundle.tgz" windows-gui

log "pack Windows helper scripts"
tar -czf "${TMP_DIR}/windows-helpers.tgz" \
  -C "${ROOT_DIR}/scripts" \
  run-windows-gui-shell.ps1 \
  smoke-windows-wintun.ps1 \
  windows-desktop-generic-turn.ps1 \
  windows-wireguard-health-capture.ps1 \
  windows-desktop-throughput-capture.ps1

log "generate guest-side lab launcher"
cat > "${TMP_DIR}/run-vm-lab-shell.ps1" <<'EOF'
param(
    [string]$BundleRoot = 'C:\Users\codex\vk-turn-lab\bundle\windows-gui',
    [string]$ListenAddress = '127.0.0.1:7777',
    [int]$StartupTimeoutSeconds = 15
)

$ErrorActionPreference = 'Stop'

$clientdPath = Join-Path $BundleRoot 'clientd.exe'
$relayDockPath = Join-Path $BundleRoot 'RelayDock.exe'
$wintunPath = Join-Path $BundleRoot 'wintun.dll'
$guiPath = if (Test-Path $relayDockPath) { $relayDockPath } else { throw "bundled RelayDock.exe not found under $BundleRoot" }
if (-not (Test-Path $clientdPath)) { throw "bundled clientd.exe not found under $BundleRoot" }
if (-not (Test-Path $wintunPath)) { throw "bundled wintun.dll not found under $BundleRoot" }

function Wait-HostReady {
    param([string]$HostUrl, [int]$TimeoutSeconds)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "$HostUrl/v1/host" -TimeoutSec 2
            if ($response.StatusCode -eq 200) { return }
        } catch {
        }
        Start-Sleep -Milliseconds 250
    }
    throw "clientd did not become ready on $HostUrl within ${TimeoutSeconds}s"
}

$hostUrl = "http://$ListenAddress"
$clientdProcess = $null
try {
    $clientdProcess = Start-Process -FilePath $clientdPath -ArgumentList @('-listen', $ListenAddress) -WorkingDirectory $BundleRoot -PassThru
    Wait-HostReady -HostUrl $hostUrl -TimeoutSeconds $StartupTimeoutSeconds
    $guiProcess = Start-Process -FilePath $guiPath -WorkingDirectory $BundleRoot -PassThru
    Write-Host "clientd pid=$($clientdProcess.Id) ready on $ListenAddress"
    Write-Host "gui pid=$($guiProcess.Id) started from $guiPath"
    Wait-Process -Id $guiProcess.Id -ErrorAction Stop
}
finally {
    if ($null -ne $clientdProcess) {
        $ownedClientd = Get-Process -Id $clientdProcess.Id -ErrorAction SilentlyContinue
        if ($null -ne $ownedClientd -and $ownedClientd.ProcessName -eq 'clientd') {
            Stop-Process -Id $ownedClientd.Id -Force -ErrorAction SilentlyContinue
            Wait-Process -Id $ownedClientd.Id -Timeout 5 -ErrorAction SilentlyContinue
        }
    }
}
EOF

log "generate guest-side host smoke"
cat > "${TMP_DIR}/assert-vm-lab-host.ps1" <<'EOF'
param(
    [string]$BundleRoot = 'C:\Users\codex\vk-turn-lab\bundle\windows-gui',
    [string]$ListenAddress = '127.0.0.1:17779',
    [int]$StartupTimeoutSeconds = 15,
    [switch]$SkipAdminCheck,
    [switch]$RequireWireGuardProfile,
    [string]$WireGuardProfilePath = 'C:\Users\codex\.local\state\vk-turn-proxy-go\wg\desktop1-windows.conf'
)

$ErrorActionPreference = 'Stop'

function Test-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Wait-HostReady {
    param([string]$HostUrl, [int]$TimeoutSeconds)
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "$HostUrl/v1/host" -TimeoutSec 2
            if ($response.StatusCode -eq 200) { return }
        } catch {
        }
        Start-Sleep -Milliseconds 250
    }
    throw "clientd did not become ready on $HostUrl within ${TimeoutSeconds}s"
}

$clientdPath = Join-Path $BundleRoot 'clientd.exe'
$relayDockPath = Join-Path $BundleRoot 'RelayDock.exe'
$wintunPath = Join-Path $BundleRoot 'wintun.dll'

if (-not (Test-Path $clientdPath)) { throw "bundled clientd.exe not found under $BundleRoot" }
if (-not (Test-Path $relayDockPath)) { throw "bundled RelayDock.exe not found under $BundleRoot" }
if (-not (Test-Path $wintunPath)) { throw "bundled wintun.dll not found under $BundleRoot" }
if (-not $SkipAdminCheck -and -not (Test-IsAdmin)) {
    throw "Windows VM lab host smoke requires an elevated PowerShell session"
}
if ($RequireWireGuardProfile -and -not (Test-Path $WireGuardProfilePath)) {
    throw "validated WireGuard profile not found: $WireGuardProfilePath"
}

$hostUrl = "http://$ListenAddress"
$clientdProcess = $null
try {
    $clientdProcess = Start-Process -FilePath $clientdPath -ArgumentList @('-listen', $ListenAddress) -WorkingDirectory $BundleRoot -PassThru
    Wait-HostReady -HostUrl $hostUrl -TimeoutSeconds $StartupTimeoutSeconds
    $hostInfo = Invoke-RestMethod -Uri "$HostUrl/v1/host" -TimeoutSec 5
    if ($hostInfo.build.target -notlike 'windows/*') {
        throw "expected windows build target, got $($hostInfo.build.target)"
    }
    $capability = @($hostInfo.platform_tunnels | Where-Object { $_.mode -eq 'windows_wintun' }) | Select-Object -First 1
    if ($null -eq $capability) {
        throw "host did not report windows_wintun platform_tunnels capability"
    }
    if (-not $capability.available) {
        throw "windows_wintun is not available: $($capability.message)"
    }
    if (-not (@($capability.supported_underlay_route_policies) -contains 'preserve_active_local_network')) {
        throw "windows_wintun capability is missing preserve_active_local_network support"
    }
    $supportedPlan = @($capability.execution_plans | Where-Object {
        $_.support_state -eq 'supported' -and
        $_.plan.access_method -eq 'turn_credentials' -and
        $_.plan.carrier_family -eq 'turn_datagram' -and
        $_.plan.engine_family -eq 'wireguard_native' -and
        $_.plan.host_adapter -eq 'windows_wintun'
    }) | Select-Object -First 1
    if ($null -eq $supportedPlan) {
        throw "windows_wintun capability is missing a supported turn_credentials/turn_datagram/wireguard_native/windows_wintun execution plan"
    }

    [pscustomobject]@{
        ok = $true
        bundle_root = $BundleRoot
        listen_address = $ListenAddress
        build_target = $hostInfo.build.target
        windows_wintun_available = [bool]$capability.available
        supported_underlay_route_policies = @($capability.supported_underlay_route_policies)
        wireguard_profile_present = [bool](Test-Path $WireGuardProfilePath)
        require_wireguard_profile = [bool]$RequireWireGuardProfile.IsPresent
    } | ConvertTo-Json -Depth 5
}
finally {
    if ($null -ne $clientdProcess) {
        $ownedClientd = Get-Process -Id $clientdProcess.Id -ErrorAction SilentlyContinue
        if ($null -ne $ownedClientd -and $ownedClientd.ProcessName -eq 'clientd') {
            Stop-Process -Id $ownedClientd.Id -Force -ErrorAction SilentlyContinue
            Wait-Process -Id $ownedClientd.Id -Timeout 5 -ErrorAction SilentlyContinue
        }
    }
}
EOF

log "ensure guest lab directories"
ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_HOST}" \
  "powershell -NoProfile -Command \"New-Item -ItemType Directory -Force -Path '${VM_LAB_ROOT}','${VM_LAB_ROOT}\\bundle','${VM_LAB_ROOT}\\artifacts','${VM_LAB_ROOT}\\scripts','${VM_HOME_DIR}\\.local\\state\\vk-turn-proxy-go\\wg' | Out-Null\""

log "upload bundle and helper archives"
scp -O "${SSH_OPTS[@]}" "${TMP_DIR}/windows-gui-bundle.tgz" "${VM_USER}@${VM_HOST}:vk-turn-lab/windows-gui-bundle.tgz"
scp -O "${SSH_OPTS[@]}" "${TMP_DIR}/windows-helpers.tgz" "${VM_USER}@${VM_HOST}:vk-turn-lab/windows-helpers.tgz"
scp -O "${SSH_OPTS[@]}" "${TMP_DIR}/run-vm-lab-shell.ps1" "${VM_USER}@${VM_HOST}:vk-turn-lab/run-vm-lab-shell.ps1"
scp -O "${SSH_OPTS[@]}" "${TMP_DIR}/assert-vm-lab-host.ps1" "${VM_USER}@${VM_HOST}:vk-turn-lab/assert-vm-lab-host.ps1"

if [[ -f "${LOCAL_WIREGUARD_PROFILE}" ]]; then
  log "upload validated WireGuard profile"
  scp -O "${SSH_OPTS[@]}" "${LOCAL_WIREGUARD_PROFILE}" "${VM_USER}@${VM_HOST}:vk-turn-lab/desktop1-windows.conf"
else
  log "validated WireGuard profile not found locally; guest sync will skip profile bootstrap"
fi

log "extract guest artifacts"
ssh "${SSH_OPTS[@]}" "${VM_USER}@${VM_HOST}" \
  "powershell -NoProfile -Command \"Remove-Item '${VM_LAB_ROOT}\\bundle\\windows-gui' -Recurse -Force -ErrorAction SilentlyContinue; tar -xf '${VM_LAB_ROOT}\\windows-gui-bundle.tgz' -C '${VM_LAB_ROOT}\\bundle'; tar -xf '${VM_LAB_ROOT}\\windows-helpers.tgz' -C '${VM_LAB_ROOT}\\scripts'; Copy-Item '${VM_LAB_ROOT}\\run-vm-lab-shell.ps1' '${VM_LAB_ROOT}\\scripts\\run-vm-lab-shell.ps1' -Force; Copy-Item '${VM_LAB_ROOT}\\assert-vm-lab-host.ps1' '${VM_LAB_ROOT}\\scripts\\assert-vm-lab-host.ps1' -Force; if (Test-Path '${VM_LAB_ROOT}\\desktop1-windows.conf') { Copy-Item '${VM_LAB_ROOT}\\desktop1-windows.conf' '${VM_PROFILE_DEST}' -Force }\""

log "guest lab sync complete"
echo "VM host: ${VM_HOST}"
echo "Lab root: ${VM_LAB_ROOT}"
echo "Bundle root: ${VM_LAB_ROOT}\\bundle\\windows-gui"
echo "Launcher: ${VM_LAB_ROOT}\\scripts\\run-vm-lab-shell.ps1"
echo "Host smoke: ${VM_LAB_ROOT}\\scripts\\assert-vm-lab-host.ps1"
echo "Profile target: ${VM_PROFILE_DEST}"
