param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$BundleRoot = "",
    [string]$ListenAddress = "127.0.0.1:7777",
    [int]$StartupTimeoutSeconds = 15
)

$ErrorActionPreference = "Stop"

function Assert-WindowsNativePath {
    param(
        [string]$PathValue,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        throw "$Label must not be empty"
    }
    if ($PathValue.StartsWith("\")) {
        throw "$Label must be a Windows-native path, not a UNC path: $PathValue"
    }
}

function Get-ListenEndpoint {
    param(
        [string]$Value
    )

    if ($Value -notmatch "^(?<host>[^:]+):(?<port>[0-9]+)$") {
        throw "listen address must be host:port, got: $Value"
    }

    return @{
        Host = $Matches["host"]
        Port = [int]$Matches["port"]
    }
}

function Wait-HostReady {
    param(
        [string]$HostUrl,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        try {
            $response = Invoke-WebRequest -UseBasicParsing -Uri "$HostUrl/v1/host" -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                return
            }
        }
        catch {
        }
        Start-Sleep -Milliseconds 250
    }

    throw "clientd did not become ready on $HostUrl within ${TimeoutSeconds}s"
}

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
Assert-WindowsNativePath -PathValue $resolvedRepoRoot -Label "RepoRoot"

if ([string]::IsNullOrWhiteSpace($BundleRoot)) {
    $BundleRoot = Join-Path $resolvedRepoRoot "dist\windows-gui"
}
$resolvedBundleRoot = (Resolve-Path $BundleRoot).Path
Assert-WindowsNativePath -PathValue $resolvedBundleRoot -Label "BundleRoot"

$clientdPath = Join-Path $resolvedBundleRoot "clientd.exe"
$guiPath = Join-Path $resolvedBundleRoot "gui_shell.exe"
if (-not (Test-Path $clientdPath)) {
    throw "bundled clientd.exe not found: $clientdPath"
}
if (-not (Test-Path $guiPath)) {
    throw "bundled gui_shell.exe not found: $guiPath"
}

$endpoint = Get-ListenEndpoint -Value $ListenAddress
$hostUrl = "http://$ListenAddress"
$listener = Get-NetTCPConnection `
    -LocalAddress $endpoint.Host `
    -LocalPort $endpoint.Port `
    -State Listen `
    -ErrorAction SilentlyContinue

if ($null -ne $listener) {
    $existing = Get-Process -Id $listener.OwningProcess -ErrorAction Stop
    if ($existing.ProcessName -ne "clientd") {
        throw "port $ListenAddress is already owned by process $($existing.ProcessName) pid=$($existing.Id)"
    }

    Write-Host "Stopping existing clientd pid=$($existing.Id) on $ListenAddress"
    Stop-Process -Id $existing.Id -Force
    Start-Sleep -Seconds 1
}

$clientdProcess = Start-Process `
    -FilePath $clientdPath `
    -ArgumentList @("-listen", $ListenAddress) `
    -WorkingDirectory $resolvedBundleRoot `
    -PassThru

Wait-HostReady -HostUrl $hostUrl -TimeoutSeconds $StartupTimeoutSeconds

$guiProcess = Start-Process `
    -FilePath $guiPath `
    -WorkingDirectory $resolvedBundleRoot `
    -PassThru

Write-Host "clientd pid=$($clientdProcess.Id) ready on $ListenAddress"
Write-Host "gui_shell pid=$($guiProcess.Id) started from $guiPath"
