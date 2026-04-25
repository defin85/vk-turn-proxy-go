param(
    [string]$BundleRoot = 'C:\Users\codex\vk-turn-lab\bundle\windows-gui',
    [string]$HostListenAddress = '127.0.0.1:17779',
    [string]$RuntimeListenAddr = '127.0.0.1:39010',
    [string]$PeerAddr = '176.109.104.105:56040',
    [string]$TurnLink = '',
    [string]$ResolutionId = '',
    [string]$ProfileId = 'desktop-generic-turn',
    [string]$LogLevel = 'debug',
    [int]$ResolutionTimeoutSeconds = 15,
    [int]$StartupTimeoutSeconds = 90,
    [int]$StopTimeoutSeconds = 20,
    [switch]$SkipAdminCheck,
    [switch]$RequireWireGuardProfile,
    [string]$WireGuardProfilePath = 'C:\Users\codex\.local\state\vk-turn-proxy-go\wg\desktop1-windows.conf',
    [switch]$NoCleanup
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

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
            if ($response.StatusCode -eq 200) {
                return
            }
        } catch {
        }
        Start-Sleep -Milliseconds 250
    }

    throw "clientd did not become ready on $HostUrl within ${TimeoutSeconds}s"
}

function Invoke-ControlPlane {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null,
        [int]$TimeoutSeconds = 30
    )

    $uri = "$script:BaseHostUrl$Path"
    $httpClient = New-Object System.Net.Http.HttpClient
    try {
        $httpClient.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
        $request = New-Object System.Net.Http.HttpRequestMessage([System.Net.Http.HttpMethod]::new($Method), $uri)
        if ($null -ne $Body) {
            $json = $Body | ConvertTo-Json -Depth 12
            $request.Content = New-Object System.Net.Http.StringContent($json, [System.Text.Encoding]::UTF8, 'application/json')
        }

        $response = $httpClient.SendAsync($request).GetAwaiter().GetResult()
        $responseBody = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $statusCode = [int]$response.StatusCode
        if (-not $response.IsSuccessStatusCode) {
            if (-not [string]::IsNullOrWhiteSpace($responseBody)) {
                throw "request failed: $Method ${uri} [$statusCode]: $responseBody"
            }
            throw "request failed: $Method ${uri} [$statusCode]: $($response.ReasonPhrase)"
        }
        if ([string]::IsNullOrWhiteSpace($responseBody)) {
            return $null
        }
        return $responseBody | ConvertFrom-Json
    } catch {
        throw
    } finally {
        if ($null -ne $request) {
            $request.Dispose()
        }
        $httpClient.Dispose()
    }
}

function Get-SortTimestamp {
    param([object]$Record)

    foreach ($field in @('updated_at', 'resolved_at', 'started_at', 'created_at')) {
        $value = $Record.$field
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return [DateTimeOffset]::Parse($value).UtcDateTime
        }
    }
    return [DateTime]::MinValue
}

function Select-WindowsWintunCapability {
    param([object]$HostInfo)

    $capability = @($HostInfo.platform_tunnels | Where-Object { $_.mode -eq 'windows_wintun' }) | Select-Object -First 1
    if ($null -eq $capability) {
        throw 'host did not report windows_wintun platform_tunnels capability'
    }
    if (-not $capability.available) {
        throw "windows_wintun is not available: $($capability.message)"
    }
    if (-not (@($capability.supported_underlay_route_policies) -contains 'preserve_active_local_network')) {
        throw 'windows_wintun capability is missing preserve_active_local_network support'
    }
    return $capability
}

function Select-WindowsExecutionPlan {
    param([object]$Capability)

    $candidates = @($Capability.execution_plans | Where-Object {
        $_.support_state -eq 'supported' -and
        $_.plan.access_method -eq 'turn_credentials' -and
        $_.plan.carrier_family -eq 'turn_datagram' -and
        $_.plan.engine_family -eq 'wireguard_native' -and
        $_.plan.host_adapter -eq 'windows_wintun'
    })
    if ($candidates.Count -eq 0) {
        throw 'windows_wintun capability is missing a supported turn_credentials/turn_datagram/wireguard_native/windows_wintun execution plan'
    }
    $default = @($candidates | Where-Object { $_.default -eq $true }) | Select-Object -First 1
    if ($null -ne $default) {
        return $default.plan
    }
    return $candidates[0].plan
}

function Get-Profiles {
    $profiles = Invoke-ControlPlane -Method 'GET' -Path '/v1/profiles'
    if ($null -eq $profiles) {
        return @()
    }
    return @($profiles)
}

function Resolve-TurnLink {
    $candidate = $TurnLink.Trim()
    if (-not [string]::IsNullOrWhiteSpace($candidate)) {
        return $candidate
    }

    $profiles = Get-Profiles
    if ($profiles.Count -eq 0) {
        return ''
    }

    if (-not [string]::IsNullOrWhiteSpace($ProfileId)) {
        $matchingProfile = @($profiles | Where-Object {
            $_.id -eq $ProfileId -and
            $_.spec.provider -eq 'generic-turn' -and
            -not [string]::IsNullOrWhiteSpace($_.spec.link)
        }) | Select-Object -First 1
        if ($null -ne $matchingProfile) {
            return [string]$matchingProfile.spec.link
        }
    }

    $latestGenericTurn = @($profiles | Where-Object {
        $_.spec.provider -eq 'generic-turn' -and
        -not [string]::IsNullOrWhiteSpace($_.spec.link)
    } | Sort-Object `
        @{ Expression = { Get-SortTimestamp $_ }; Descending = $true }, `
        @{ Expression = { $_.id }; Descending = $true }) | Select-Object -First 1
    if ($null -ne $latestGenericTurn) {
        return [string]$latestGenericTurn.spec.link
    }

    return ''
}

function Get-Resolutions {
    $resolutions = Invoke-ControlPlane -Method 'GET' -Path '/v1/resolutions'
    if ($null -eq $resolutions) {
        return @()
    }
    return @($resolutions)
}

function Wait-ResolutionResolved {
    param([string]$TargetResolutionId)

    $deadline = (Get-Date).AddSeconds($ResolutionTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $resolution = Invoke-ControlPlane -Method 'GET' -Path "/v1/resolutions/$TargetResolutionId" -TimeoutSeconds 10
        if ($resolution.state -ne 'starting') {
            return $resolution
        }
        Start-Sleep -Milliseconds 500
    }

    throw "timed out waiting for resolution $TargetResolutionId to finish"
}

function Ensure-ResolvedResolution {
    $resolvedId = $ResolutionId.Trim()
    if (-not [string]::IsNullOrWhiteSpace($resolvedId)) {
        $resolved = Wait-ResolutionResolved -TargetResolutionId $resolvedId
        if ($resolved.state -ne 'resolved') {
            throw 'resolution ' + $resolvedId + ' is not resolved: ' + ($resolved | ConvertTo-Json -Depth 12 -Compress)
        }
        return $resolved
    }

    $turnLink = Resolve-TurnLink
    if (-not [string]::IsNullOrWhiteSpace($turnLink)) {
        $resolution = Invoke-ControlPlane -Method 'POST' -Path '/v1/resolutions' -Body @{
            provider = 'generic-turn'
            input = @{
                kind = 'link'
                link = $turnLink
            }
        } -TimeoutSeconds 15
        $createdId = [string]$resolution.id
        if ([string]::IsNullOrWhiteSpace($createdId)) {
            throw 'resolution response did not include an id'
        }
        $resolved = Wait-ResolutionResolved -TargetResolutionId $createdId
        if ($resolved.state -ne 'resolved') {
            throw 'resolution ' + $createdId + ' did not reach resolved state: ' + ($resolved | ConvertTo-Json -Depth 12 -Compress)
        }
        return $resolved
    }

    $latest = @(
        Get-Resolutions | Where-Object { $_.state -eq 'resolved' } | Sort-Object `
            @{ Expression = { Get-SortTimestamp $_ }; Descending = $true }, `
            @{ Expression = { $_.id }; Descending = $true }
    ) | Select-Object -First 1
    if ($null -eq $latest) {
        throw 'ready=true smoke requires -TurnLink, -ResolutionId, or a saved generic-turn profile with a reusable link'
    }
    return $latest
}

function Wait-SessionState {
    param(
        [string]$SessionId,
        [string]$ExpectedState,
        [int]$TimeoutSeconds
    )

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $session = Invoke-ControlPlane -Method 'GET' -Path "/v1/sessions/$SessionId" -TimeoutSeconds 10
        if ($session.state -eq $ExpectedState) {
            return $session
        }
        Start-Sleep -Milliseconds 500
    }

    throw "session $SessionId did not reach $ExpectedState within ${TimeoutSeconds}s"
}

$clientdPath = Join-Path $BundleRoot 'clientd.exe'
$relayDockPath = Join-Path $BundleRoot 'RelayDock.exe'
$wintunPath = Join-Path $BundleRoot 'wintun.dll'

if (-not (Test-Path $clientdPath)) { throw "bundled clientd.exe not found under $BundleRoot" }
if (-not (Test-Path $relayDockPath)) { throw "bundled RelayDock.exe not found under $BundleRoot" }
if (-not (Test-Path $wintunPath)) { throw "bundled wintun.dll not found under $BundleRoot" }
if (-not $SkipAdminCheck -and -not (Test-IsAdmin)) {
    throw 'Windows Wintun smoke requires an elevated PowerShell session'
}
if ($RequireWireGuardProfile -and -not (Test-Path $WireGuardProfilePath)) {
    throw "validated WireGuard profile not found: $WireGuardProfilePath"
}
if (Test-Path $WireGuardProfilePath) {
    $env:VKTP_WINDOWS_WIREGUARD_PROFILE = $WireGuardProfilePath
}

$script:BaseHostUrl = "http://$HostListenAddress"
$clientdProcess = $null
$startResult = $null

try {
    $clientdProcess = Start-Process -FilePath $clientdPath -ArgumentList @('-listen', $HostListenAddress) -WorkingDirectory $BundleRoot -PassThru
    Wait-HostReady -HostUrl $script:BaseHostUrl -TimeoutSeconds 15

    $hostInfo = Invoke-ControlPlane -Method 'GET' -Path '/v1/host' -TimeoutSeconds 10
    if ($hostInfo.build.target -notlike 'windows/*') {
        throw "expected windows build target, got $($hostInfo.build.target)"
    }
    $capability = Select-WindowsWintunCapability -HostInfo $hostInfo
    $executionPlan = Select-WindowsExecutionPlan -Capability $capability
    $resolution = Ensure-ResolvedResolution
    $resolvedId = [string]$resolution.id

    $startPayload = @{
        mode = 'windows_wintun'
        resolution_id = $resolvedId
        execution_plan = $executionPlan
        runtime_defaults = @{
            listen_addr = $RuntimeListenAddr
            peer_addr = $PeerAddr
            connections = 1
            mode = 'auto'
            use_dtls = $true
            log_level = $LogLevel
        }
        underlay_route_policy = 'preserve_active_local_network'
    }

    $startResult = Invoke-ControlPlane -Method 'POST' -Path '/v1/platform-tunnels/start' -Body $startPayload -TimeoutSeconds $StartupTimeoutSeconds
    if ($startResult.ready -ne $true) {
        throw 'windows_wintun did not reach ready=true: ' + ($startResult | ConvertTo-Json -Depth 12 -Compress)
    }
    if ([string]::IsNullOrWhiteSpace([string]$startResult.session_id)) {
        throw 'windows_wintun ready result did not include session_id'
    }

    $session = Wait-SessionState -SessionId ([string]$startResult.session_id) -ExpectedState 'ready' -TimeoutSeconds 10
    if ([string]$session.source_resolution_id -ne $resolvedId) {
        throw "ready session source_resolution_id $($session.source_resolution_id) does not match $resolvedId"
    }

    [pscustomobject]@{
        ok = $true
        host_listen_address = $HostListenAddress
        resolution_id = $resolvedId
        session_id = [string]$startResult.session_id
        execution_plan = $startResult.execution_plan
        underlay_route_policy = [string]$startResult.underlay_route_policy
        host_build = $hostInfo.build
        session_state = [string]$session.state
        wireguard_profile_present = [bool](Test-Path $WireGuardProfilePath)
        require_wireguard_profile = [bool]$RequireWireGuardProfile.IsPresent
    } | ConvertTo-Json -Depth 12
}
finally {
    if (-not $NoCleanup -and $null -ne $startResult -and $startResult.ready -eq $true) {
        try {
            $stopResult = Invoke-ControlPlane -Method 'POST' -Path '/v1/platform-tunnels/stop' -Body @{
                mode = 'windows_wintun'
            } -TimeoutSeconds $StopTimeoutSeconds
            if ($stopResult.stopped -ne $true) {
                throw 'windows_wintun stop did not report stopped=true'
            }
            [void](Wait-SessionState -SessionId ([string]$startResult.session_id) -ExpectedState 'stopped' -TimeoutSeconds 10)
        } catch {
            Write-Warning "cleanup failed: $($_.Exception.Message)"
        }
    }

    if ($null -ne $clientdProcess) {
        $ownedClientd = Get-Process -Id $clientdProcess.Id -ErrorAction SilentlyContinue
        if ($null -ne $ownedClientd -and $ownedClientd.ProcessName -eq 'clientd') {
            Stop-Process -Id $ownedClientd.Id -Force -ErrorAction SilentlyContinue
            Wait-Process -Id $ownedClientd.Id -Timeout 5 -ErrorAction SilentlyContinue
        }
    }
}
