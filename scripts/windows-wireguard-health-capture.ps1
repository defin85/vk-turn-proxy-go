param(
    [string]$HostUrl = "http://127.0.0.1:7777",
    [string]$OutputDir = "",
    [string]$SessionId = "",
    [string]$ProfileId = "",
    [int]$SampleIntervalSeconds = 2,
    [int]$DurationSeconds = 120,
    [int]$WaitForSessionSeconds = 5,
    [string]$ExternalProbeIP = "1.1.1.1",
    [string]$DnsProbeName = "example.com"
)

$ErrorActionPreference = "Stop"

if ($SampleIntervalSeconds -le 0) {
    throw "SampleIntervalSeconds must be greater than zero"
}
if ($DurationSeconds -lt 0) {
    throw "DurationSeconds must be zero or greater"
}
if ($WaitForSessionSeconds -lt 0) {
    throw "WaitForSessionSeconds must be zero or greater"
}

function Write-JsonFile {
    param(
        [string]$Path,
        [object]$Value
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $Value | ConvertTo-Json -Depth 16 | Set-Content -Path $Path -Encoding utf8
}

function Write-TextFile {
    param(
        [string]$Path,
        [string]$Value
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $Value | Set-Content -Path $Path -Encoding utf8
}

function Append-Ndjson {
    param(
        [string]$Path,
        [object]$Value
    )

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory)) {
        New-Item -ItemType Directory -Force -Path $directory | Out-Null
    }
    $Value | ConvertTo-Json -Compress -Depth 12 | Add-Content -Path $Path -Encoding utf8
}

function New-OutputPaths {
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $captureRoot = $OutputDir
    if ([string]::IsNullOrWhiteSpace($captureRoot)) {
        $captureRoot = Join-Path $repoRoot "artifacts\windows-wireguard-health\$timestamp"
    }

    $resolved = [System.IO.Path]::GetFullPath($captureRoot)
    $samplesDir = Join-Path $resolved "samples"
    New-Item -ItemType Directory -Force -Path $samplesDir | Out-Null

    return @{
        Root              = $resolved
        Samples           = $samplesDir
        Manifest          = (Join-Path $resolved "manifest.json")
        SummaryCsv        = (Join-Path $resolved "summary.csv")
        SummaryNdjson     = (Join-Path $resolved "summary.ndjson")
        ErrorsNdjson      = (Join-Path $resolved "errors.ndjson")
        HostInitial       = (Join-Path $resolved "host-initial.json")
        SessionsInitial   = (Join-Path $resolved "sessions-initial.json")
        HostFinal         = (Join-Path $resolved "host-final.json")
        SessionsFinal     = (Join-Path $resolved "sessions-final.json")
        RoutePrintInitial = (Join-Path $resolved "route-print-initial.txt")
        RoutePrintFinal   = (Join-Path $resolved "route-print-final.txt")
        IpconfigInitial   = (Join-Path $resolved "ipconfig-initial.txt")
        IpconfigFinal     = (Join-Path $resolved "ipconfig-final.txt")
        WGShowInitial     = (Join-Path $resolved "wg-show-initial.txt")
        WGShowFinal       = (Join-Path $resolved "wg-show-final.txt")
        LatestSample      = (Join-Path $resolved "latest-sample.json")
    }
}

function Try-InvokeControlPlane {
    param(
        [string]$Method,
        [string]$Path
    )

    $base = $script:BaseHostUrl.TrimEnd("/")
    $uri = "$base$Path"
    try {
        $value = Invoke-RestMethod -Method $Method -Uri $uri -ContentType "application/json" -TimeoutSec 3
        return @{
            ok    = $true
            uri   = $uri
            value = $value
        }
    }
    catch {
        return @{
            ok    = $false
            uri   = $uri
            error = $_.Exception.Message
        }
    }
}

function Get-SessionsSafe {
    $result = Try-InvokeControlPlane -Method "GET" -Path "/v1/sessions"
    if (-not $result.ok) {
        return $result
    }

    if ($null -eq $result.value) {
        $result.value = @()
    }
    else {
        $result.value = @($result.value)
    }
    return $result
}

function Get-SortTimestamp {
    param(
        [object]$Session
    )

    foreach ($field in @("updated_at", "started_at")) {
        $value = $Session.$field
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            return [DateTimeOffset]::Parse($value).UtcDateTime
        }
    }

    return [DateTime]::MinValue
}

function Get-LatestSession {
    param(
        [object[]]$Sessions,
        [string]$TargetProfileId = ""
    )

    $pool = @($Sessions)
    if (-not [string]::IsNullOrWhiteSpace($TargetProfileId)) {
        $pool = @($pool | Where-Object { $_.profile_id -eq $TargetProfileId })
    }
    if ($pool.Count -eq 0) {
        return $null
    }

    $activeStates = @("starting", "challenge_required", "ready", "retrying")
    $active = @($pool | Where-Object { $activeStates -contains $_.state })
    if ($active.Count -gt 0) {
        $pool = $active
    }

    return $pool |
        Sort-Object `
            @{ Expression = { Get-SortTimestamp $_ }; Descending = $true }, `
            @{ Expression = { $_.id }; Descending = $true } |
        Select-Object -First 1
}

function Resolve-TargetSession {
    $deadline = (Get-Date).AddSeconds($WaitForSessionSeconds)

    while ($true) {
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $sessionResult = Try-InvokeControlPlane -Method "GET" -Path "/v1/sessions/$SessionId"
            if ($sessionResult.ok) {
                return @{
                    ok      = $true
                    session = $sessionResult.value
                }
            }
        }
        else {
            $sessionsResult = Get-SessionsSafe
            if ($sessionsResult.ok) {
                $latest = Get-LatestSession -Sessions $sessionsResult.value -TargetProfileId $ProfileId
                if ($null -ne $latest) {
                    return @{
                        ok      = $true
                        session = $latest
                    }
                }
            }
        }

        if ((Get-Date) -ge $deadline) {
            break
        }
        Start-Sleep -Milliseconds 500
    }

    return @{
        ok    = $false
        error = "no matching session became available"
    }
}

function Parse-MetricSamples {
    param(
        [string]$MetricsText
    )

    $samples = @()
    foreach ($line in ($MetricsText -split "`r?`n")) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            continue
        }
        if ($line -notmatch "^(?<name>[^{ ]+)(?:\{(?<labels>[^}]*)\})?\s+(?<value>[-+0-9.eE]+)$") {
            continue
        }

        $labels = @{}
        $labelText = $Matches["labels"]
        if (-not [string]::IsNullOrWhiteSpace($labelText)) {
            foreach ($item in ($labelText -split ",")) {
                $key, $rawValue = $item -split "=", 2
                if ([string]::IsNullOrWhiteSpace($key)) {
                    continue
                }
                $labels[$key.Trim()] = $rawValue.Trim().Trim('"')
            }
        }

        $samples += [pscustomobject]@{
            Name   = $Matches["name"]
            Labels = $labels
            Value  = [double]$Matches["value"]
        }
    }

    return $samples
}

function Measure-MetricTotal {
    param(
        [object[]]$MetricSamples,
        [string]$Name,
        [hashtable]$RequiredLabels = @{}
    )

    $found = $false
    $sum = 0.0
    foreach ($sample in $MetricSamples) {
        if ($sample.Name -ne $Name) {
            continue
        }

        $matches = $true
        foreach ($key in $RequiredLabels.Keys) {
            if ($sample.Labels[$key] -ne $RequiredLabels[$key]) {
                $matches = $false
                break
            }
        }
        if (-not $matches) {
            continue
        }

        $sum += [double]$sample.Value
        $found = $true
    }

    if ($found) {
        return $sum
    }
    return $null
}

function Split-HostPort {
    param(
        [string]$Endpoint
    )

    if ([string]::IsNullOrWhiteSpace($Endpoint)) {
        return $null
    }
    if ($Endpoint -notmatch "^(?<host>.+):(?<port>[0-9]+)$") {
        return $null
    }

    return @{
        host = $Matches["host"]
        port = [int]$Matches["port"]
    }
}

function Get-DefaultGateway {
    $route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue |
        Sort-Object RouteMetric, InterfaceMetric |
        Select-Object -First 1

    if ($null -eq $route) {
        return $null
    }
    if ([string]::IsNullOrWhiteSpace($route.NextHop) -or $route.NextHop -eq "0.0.0.0") {
        return $null
    }
    return [string]$route.NextHop
}

function Get-WGShowText {
    $wgExe = Join-Path ${env:ProgramFiles} "WireGuard\wg.exe"
    if (-not (Test-Path $wgExe)) {
        return ""
    }

    try {
        return (& $wgExe show 2>&1 | Out-String).Trim()
    }
    catch {
        return "wg_show_failed: $($_.Exception.Message)"
    }
}

function Invoke-Probe {
    param(
        [string]$Target
    )

    if ([string]::IsNullOrWhiteSpace($Target)) {
        return @{
            ok    = $false
            error = "target is empty"
        }
    }

    try {
        $pingOutput = (& ping.exe -n 1 -w 1000 $Target 2>&1 | Out-String).Trim()
        $exitCode = $LASTEXITCODE
        return @{
            ok             = $true
            target         = $Target
            ping_succeeded = ($exitCode -eq 0)
            raw_output     = $pingOutput
        }
    }
    catch {
        return @{
            ok    = $false
            target = $Target
            error = $_.Exception.Message
        }
    }
}

function Invoke-DnsProbe {
    param(
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return @{
            ok    = $false
            error = "name is empty"
        }
    }

    try {
        $records = @(Resolve-DnsName -Name $Name -QuickTimeout -ErrorAction Stop)
        return @{
            ok      = $true
            name    = $Name
            answers = @($records | Select-Object Name,Type,IPAddress,NameHost,Section)
        }
    }
    catch {
        return @{
            ok    = $false
            name  = $Name
            error = $_.Exception.Message
        }
    }
}

function Get-PublicHostRoutes {
    return @(
        Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object {
                $_.DestinationPrefix -match '^\d+\.\d+\.\d+\.\d+/32$' -and
                $_.DestinationPrefix -notlike '127.*' -and
                $_.DestinationPrefix -notlike '169.254.*' -and
                $_.DestinationPrefix -notlike '192.168.*' -and
                $_.DestinationPrefix -notlike '172.1[6-9].*' -and
                $_.DestinationPrefix -notlike '172.2[0-9].*' -and
                $_.DestinationPrefix -notlike '172.3[0-1].*' -and
                $_.DestinationPrefix -notlike '10.*'
            } |
            Sort-Object DestinationPrefix, RouteMetric, InterfaceMetric |
            Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric, InterfaceMetric, State
    )
}

function Get-NetworkStateSnapshot {
    param(
        [object]$ResolvedSession
    )

    $wgShowText = Get-WGShowText
    $peer = $null
    if ($null -ne $ResolvedSession -and $null -ne $ResolvedSession.profile) {
        $peer = Split-HostPort -Endpoint ([string]$ResolvedSession.profile.peer_addr)
    }
    $gateway = Get-DefaultGateway

    return @{
        wg_services        = @(Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'WireGuard*' -or $_.DisplayName -like 'WireGuard*' } | Select-Object Name, DisplayName, Status, StartType)
        wintun_adapters    = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -like 'Wintun*' } | Select-Object Name, InterfaceDescription, Status, InterfaceIndex, MacAddress, LinkSpeed)
        net_adapters       = @(Get-NetAdapter -ErrorAction SilentlyContinue | Select-Object Name, InterfaceDescription, Status, InterfaceIndex, MacAddress, LinkSpeed)
        ip_addresses       = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, IPAddress, PrefixLength, Type)
        ip_interfaces      = @(Get-NetIPInterface -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object InterfaceAlias, InterfaceIndex, AddressFamily, ConnectionState, Dhcp, InterfaceMetric, NlMtu)
        default_routes     = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue | Sort-Object RouteMetric, InterfaceMetric | Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric, InterfaceMetric, State)
        split_routes       = @(Get-NetRoute -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.DestinationPrefix -in @("0.0.0.0/1", "128.0.0.0/1") } | Sort-Object DestinationPrefix, RouteMetric, InterfaceMetric | Select-Object DestinationPrefix, NextHop, InterfaceAlias, RouteMetric, InterfaceMetric, State)
        public_host_routes = @(Get-PublicHostRoutes)
        gateway_ip         = $gateway
        peer_endpoint      = if ($null -ne $peer) { $peer } else { $null }
        probes             = @{
            gateway  = Invoke-Probe -Target $gateway
            peer     = if ($null -ne $peer) { Invoke-Probe -Target $peer.host } else { @{ ok = $false; error = "peer host unavailable" } }
            external = Invoke-Probe -Target $ExternalProbeIP
            dns      = Invoke-DnsProbe -Name $DnsProbeName
        }
        wg_show            = $wgShowText
    }
}

function Get-ControlPlaneSnapshot {
    param(
        [object]$PreferredSession
    )

    $hostResult = Try-InvokeControlPlane -Method "GET" -Path "/v1/host"
    $sessionsResult = Get-SessionsSafe
    $sessionResult = $null
    if ($null -ne $PreferredSession) {
        $sessionResult = Try-InvokeControlPlane -Method "GET" -Path "/v1/sessions/$($PreferredSession.id)"
    }
    elseif ($sessionsResult.ok) {
        $latest = Get-LatestSession -Sessions $sessionsResult.value -TargetProfileId $ProfileId
        if ($null -ne $latest) {
            $sessionResult = Try-InvokeControlPlane -Method "GET" -Path "/v1/sessions/$($latest.id)"
        }
    }

    $diagnosticsResult = $null
    if ($null -ne $sessionResult -and $sessionResult.ok) {
        $diagnosticsResult = Try-InvokeControlPlane -Method "GET" -Path "/v1/sessions/$($sessionResult.value.id)/diagnostics"
    }

    return @{
        host        = $hostResult
        sessions    = $sessionsResult
        session     = $sessionResult
        diagnostics = $diagnosticsResult
    }
}

function Build-SummaryRow {
    param(
        [int]$SampleIndex,
        [datetime]$CapturedAt,
        [object]$ControlPlane,
        [object]$NetworkState,
        [string]$SampleFile
    )

    $session = $null
    if ($null -ne $ControlPlane.session -and $ControlPlane.session.ok) {
        $session = $ControlPlane.session.value
    }

    $diagnostics = $null
    $metricSamples = @()
    if ($null -ne $ControlPlane.diagnostics -and $ControlPlane.diagnostics.ok) {
        $diagnostics = $ControlPlane.diagnostics.value
        $metricSamples = Parse-MetricSamples -MetricsText ([string]$diagnostics.metrics)
    }

    $runtimeLabels = @{ runtime = "client" }
    $wgManager = @($NetworkState.wg_services | Where-Object { $_.Name -eq "WireGuardManager" } | Select-Object -First 1)

    return [pscustomobject][ordered]@{
        sample_index                 = $SampleIndex
        captured_at                  = $CapturedAt.ToString("o")
        sample_file                  = $SampleFile
        control_plane_ok             = [bool]($ControlPlane.host.ok)
        control_plane_error          = if ($ControlPlane.host.ok) { "" } else { [string]$ControlPlane.host.error }
        session_id                   = if ($null -ne $session) { [string]$session.id } else { "" }
        session_state                = if ($null -ne $session) { [string]$session.state } else { "" }
        profile_id                   = if ($null -ne $session) { [string]$session.profile_id } else { "" }
        active_workers               = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_active_workers" -RequiredLabels $runtimeLabels
        transport_failures_total     = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_transport_stage_failures_total" -RequiredLabels $runtimeLabels
        local_to_relay_bytes         = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_forwarded_bytes_total" -RequiredLabels @{ runtime = "client"; direction = "local_to_relay" }
        relay_to_local_bytes         = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_forwarded_bytes_total" -RequiredLabels @{ runtime = "client"; direction = "relay_to_local" }
        wg_manager_status            = if ($wgManager.Count -gt 0) { [string]$wgManager[0].Status } else { "" }
        wg_show_has_peer             = [bool]([string]$NetworkState.wg_show -match 'peer:')
        wg_show_has_handshake        = [bool]([string]$NetworkState.wg_show -match 'latest handshake:')
        wintun_up_count              = @($NetworkState.wintun_adapters | Where-Object { $_.Status -eq "Up" }).Count
        split_route_count            = @($NetworkState.split_routes).Count
        public_host_route_count      = @($NetworkState.public_host_routes).Count
        gateway_ip                   = [string]$NetworkState.gateway_ip
        gateway_ping_ok              = if ($NetworkState.probes.gateway.ok) { [bool]$NetworkState.probes.gateway.ping_succeeded } else { $null }
        gateway_probe_error          = if ($NetworkState.probes.gateway.ok) { "" } else { [string]$NetworkState.probes.gateway.error }
        peer_host                    = if ($null -ne $NetworkState.peer_endpoint) { [string]$NetworkState.peer_endpoint.host } else { "" }
        peer_ping_ok                 = if ($NetworkState.probes.peer.ok) { [bool]$NetworkState.probes.peer.ping_succeeded } else { $null }
        peer_probe_error             = if ($NetworkState.probes.peer.ok) { "" } else { [string]$NetworkState.probes.peer.error }
        external_probe_ip            = $ExternalProbeIP
        external_ping_ok             = if ($NetworkState.probes.external.ok) { [bool]$NetworkState.probes.external.ping_succeeded } else { $null }
        external_probe_error         = if ($NetworkState.probes.external.ok) { "" } else { [string]$NetworkState.probes.external.error }
        dns_probe_name               = $DnsProbeName
        dns_ok                       = [bool]$NetworkState.probes.dns.ok
        dns_probe_error              = if ($NetworkState.probes.dns.ok) { "" } else { [string]$NetworkState.probes.dns.error }
    }
}

function Write-SummaryRow {
    param(
        [string]$CsvPath,
        [string]$NdjsonPath,
        [object]$Row
    )

    Append-Ndjson -Path $NdjsonPath -Value $Row
    if (Test-Path $CsvPath) {
        $Row | Export-Csv -Path $CsvPath -NoTypeInformation -Append
    }
    else {
        $Row | Export-Csv -Path $CsvPath -NoTypeInformation
    }
}

$script:BaseHostUrl = $HostUrl
$paths = New-OutputPaths
$captureStartedAt = Get-Date

$initialControlPlane = Get-ControlPlaneSnapshot -PreferredSession $null
if ($initialControlPlane.host.ok) {
    Write-JsonFile -Path $paths.HostInitial -Value $initialControlPlane.host.value
}
if ($initialControlPlane.sessions.ok) {
    Write-JsonFile -Path $paths.SessionsInitial -Value $initialControlPlane.sessions.value
}
Write-TextFile -Path $paths.RoutePrintInitial -Value ((route print | Out-String).Trim())
Write-TextFile -Path $paths.IpconfigInitial -Value ((ipconfig /all | Out-String).Trim())
Write-TextFile -Path $paths.WGShowInitial -Value (Get-WGShowText)

$resolvedSession = Resolve-TargetSession
$targetSession = $null
if ($resolvedSession.ok) {
    $targetSession = $resolvedSession.session
}

Write-JsonFile -Path $paths.Manifest -Value ([ordered]@{
    started_at               = $captureStartedAt.ToString("o")
    host_url                 = $HostUrl
    output_dir               = $paths.Root
    requested_session_id     = $SessionId
    requested_profile_id     = $ProfileId
    sample_interval_seconds  = $SampleIntervalSeconds
    duration_seconds         = $DurationSeconds
    wait_for_session_seconds = $WaitForSessionSeconds
    external_probe_ip        = $ExternalProbeIP
    dns_probe_name           = $DnsProbeName
    target_session_id        = if ($null -ne $targetSession) { [string]$targetSession.id } else { "" }
    target_profile_id        = if ($null -ne $targetSession) { [string]$targetSession.profile_id } else { "" }
    target_session_error     = if ($resolvedSession.ok) { "" } else { [string]$resolvedSession.error }
})

Write-Host "capture_dir=$($paths.Root)"
if ($null -ne $targetSession) {
    Write-Host "session_id=$($targetSession.id)"
    Write-Host "profile_id=$($targetSession.profile_id)"
}
else {
    Write-Host "session_id="
    Write-Host "profile_id="
}
Write-Host "Enable WireGuard now if you want this capture to include the transition."

$sampleCount = 0
$errorCount = 0
$deadline = if ($DurationSeconds -eq 0) { [DateTime]::MaxValue } else { (Get-Date).AddSeconds($DurationSeconds) }

while ((Get-Date) -lt $deadline) {
    $sampleCount++
    $capturedAt = Get-Date
    $sampleStamp = $capturedAt.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $sampleFileName = ("{0:D4}-{1}-sample.json" -f $sampleCount, $sampleStamp)
    $samplePath = Join-Path $paths.Samples $sampleFileName

    try {
        $controlPlane = Get-ControlPlaneSnapshot -PreferredSession $targetSession
        if ($null -eq $targetSession -and $null -ne $controlPlane.session -and $controlPlane.session.ok) {
            $targetSession = $controlPlane.session.value
        }

        $resolvedForNetwork = $targetSession
        if ($null -eq $resolvedForNetwork -and $null -ne $controlPlane.session -and $controlPlane.session.ok) {
            $resolvedForNetwork = $controlPlane.session.value
        }
        $networkState = Get-NetworkStateSnapshot -ResolvedSession $resolvedForNetwork

        $sample = [ordered]@{
            sample_index   = $sampleCount
            captured_at    = $capturedAt.ToString("o")
            control_plane  = $controlPlane
            network_state  = $networkState
        }
        Write-JsonFile -Path $samplePath -Value $sample
        Copy-Item -Path $samplePath -Destination $paths.LatestSample -Force

        $summary = Build-SummaryRow `
            -SampleIndex $sampleCount `
            -CapturedAt $capturedAt `
            -ControlPlane $controlPlane `
            -NetworkState $networkState `
            -SampleFile $sampleFileName
        Write-SummaryRow -CsvPath $paths.SummaryCsv -NdjsonPath $paths.SummaryNdjson -Row $summary

        Write-Host ("sample={0} ts={1} session={2} wintun_up={3} split_routes={4} gateway_ping={5} peer_ping={6} external_ping={7} dns_ok={8}" -f `
                $summary.sample_index,
                $summary.captured_at,
                $summary.session_state,
                $summary.wintun_up_count,
                $summary.split_route_count,
                $summary.gateway_ping_ok,
                $summary.peer_ping_ok,
                $summary.external_ping_ok,
                $summary.dns_ok)
    }
    catch {
        $errorCount++
        $errorSummary = [pscustomobject][ordered]@{
            sample_index = $sampleCount
            captured_at  = $capturedAt.ToString("o")
            error        = $_.Exception.Message
        }
        Append-Ndjson -Path $paths.ErrorsNdjson -Value $errorSummary
        Write-Warning $errorSummary.error
    }

    if ($DurationSeconds -ne 0 -and (Get-Date) -ge $deadline) {
        break
    }
    Start-Sleep -Seconds $SampleIntervalSeconds
}

$finalControlPlane = Get-ControlPlaneSnapshot -PreferredSession $targetSession
if ($finalControlPlane.host.ok) {
    Write-JsonFile -Path $paths.HostFinal -Value $finalControlPlane.host.value
}
if ($finalControlPlane.sessions.ok) {
    Write-JsonFile -Path $paths.SessionsFinal -Value $finalControlPlane.sessions.value
}
Write-TextFile -Path $paths.RoutePrintFinal -Value ((route print | Out-String).Trim())
Write-TextFile -Path $paths.IpconfigFinal -Value ((ipconfig /all | Out-String).Trim())
Write-TextFile -Path $paths.WGShowFinal -Value (Get-WGShowText)

Write-JsonFile -Path $paths.Manifest -Value ([ordered]@{
    started_at               = $captureStartedAt.ToString("o")
    host_url                 = $HostUrl
    output_dir               = $paths.Root
    requested_session_id     = $SessionId
    requested_profile_id     = $ProfileId
    sample_interval_seconds  = $SampleIntervalSeconds
    duration_seconds         = $DurationSeconds
    wait_for_session_seconds = $WaitForSessionSeconds
    external_probe_ip        = $ExternalProbeIP
    dns_probe_name           = $DnsProbeName
    target_session_id        = if ($null -ne $targetSession) { [string]$targetSession.id } else { "" }
    target_profile_id        = if ($null -ne $targetSession) { [string]$targetSession.profile_id } else { "" }
    target_session_error     = if ($resolvedSession.ok) { "" } else { [string]$resolvedSession.error }
    samples_written          = $sampleCount
    errors_written           = $errorCount
    finished_at              = (Get-Date).ToString("o")
})

Write-Host "samples_written=$sampleCount"
Write-Host "errors_written=$errorCount"
Write-Host "summary_csv=$($paths.SummaryCsv)"
Write-Host "summary_ndjson=$($paths.SummaryNdjson)"
