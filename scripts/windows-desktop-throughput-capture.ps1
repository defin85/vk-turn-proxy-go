param(
    [string]$HostUrl = "http://127.0.0.1:7777",
    [string]$OutputDir = "",
    [string]$SessionId = "",
    [string]$ProfileId = "",
    [int]$SampleIntervalSeconds = 2,
    [int]$DurationSeconds = 180,
    [int]$WaitForSessionSeconds = 30
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

$requiredCapabilities = @(
    "sessions",
    "diagnostics"
)

function Invoke-ControlPlane {
    param(
        [string]$Method,
        [string]$Path
    )

    $base = $script:BaseHostUrl.TrimEnd("/")
    $uri = "$base$Path"

    try {
        return Invoke-RestMethod -Method $Method -Uri $uri -ContentType "application/json"
    }
    catch {
        $message = $_.Exception.Message
        throw ("request failed: {0} {1}: {2}" -f $Method, $uri, $message)
    }
}

function Get-HostInfo {
    return Invoke-ControlPlane -Method "GET" -Path "/v1/host"
}

function Assert-RequiredCapabilities {
    param(
        [object]$HostInfo
    )

    $caps = @()
    if ($null -ne $HostInfo.capabilities) {
        $caps = @($HostInfo.capabilities)
    }
    foreach ($required in $requiredCapabilities) {
        if ($caps -notcontains $required) {
            throw "clientd is missing required capability: $required"
        }
    }
}

function Get-Sessions {
    $sessions = Invoke-ControlPlane -Method "GET" -Path "/v1/sessions"
    if ($null -eq $sessions) {
        return @()
    }
    return @($sessions)
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
        [string]$TargetProfileId = ""
    )

    $sessions = Get-Sessions
    if (-not [string]::IsNullOrWhiteSpace($TargetProfileId)) {
        $sessions = @($sessions | Where-Object { $_.profile_id -eq $TargetProfileId })
    }
    if ($sessions.Count -eq 0) {
        return $null
    }

    $activeStates = @("starting", "challenge_required", "ready", "retrying")
    $active = @($sessions | Where-Object { $activeStates -contains $_.state })
    $pool = $active
    if ($pool.Count -eq 0) {
        $pool = $sessions
    }

    return $pool |
        Sort-Object `
            @{ Expression = { Get-SortTimestamp $_ }; Descending = $true }, `
            @{ Expression = { $_.id }; Descending = $true } |
        Select-Object -First 1
}

function Resolve-TargetSession {
    if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
        return Invoke-ControlPlane -Method "GET" -Path "/v1/sessions/$SessionId"
    }

    $deadline = (Get-Date).AddSeconds($WaitForSessionSeconds)
    while ($true) {
        $latest = Get-LatestSession -TargetProfileId $ProfileId
        if ($null -ne $latest) {
            return $latest
        }
        if ((Get-Date) -ge $deadline) {
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if (-not [string]::IsNullOrWhiteSpace($ProfileId)) {
        throw "no desktop session found for profile_id=$ProfileId"
    }
    throw "no desktop session found"
}

function New-OutputPaths {
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    $captureRoot = $OutputDir
    if ([string]::IsNullOrWhiteSpace($captureRoot)) {
        $captureRoot = Join-Path $repoRoot "artifacts\desktop-throughput-captures\$timestamp"
    }

    $resolved = [System.IO.Path]::GetFullPath($captureRoot)
    $samplesDir = Join-Path $resolved "samples"
    New-Item -ItemType Directory -Force -Path $samplesDir | Out-Null

    return @{
        Root          = $resolved
        Samples       = $samplesDir
        Manifest      = (Join-Path $resolved "manifest.json")
        Host          = (Join-Path $resolved "host.json")
        Sessions      = (Join-Path $resolved "sessions-initial.json")
        SessionsFinal = (Join-Path $resolved "sessions-final.json")
        SummaryNdjson = (Join-Path $resolved "summary.ndjson")
        SummaryCsv    = (Join-Path $resolved "summary.csv")
        ErrorsNdjson  = (Join-Path $resolved "errors.ndjson")
        LatestDiag    = (Join-Path $resolved "latest-diagnostics.json")
        LatestMetrics = (Join-Path $resolved "latest-metrics.prom")
    }
}

function Clear-ManagedOutputArtifacts {
    param(
        [hashtable]$Paths
    )

    $managedFiles = @(
        $Paths.Manifest,
        $Paths.Host,
        $Paths.Sessions,
        $Paths.SessionsFinal,
        $Paths.SummaryNdjson,
        $Paths.SummaryCsv,
        $Paths.ErrorsNdjson,
        $Paths.LatestDiag,
        $Paths.LatestMetrics
    )

    foreach ($path in $managedFiles) {
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
        }
    }

    if (-not (Test-Path -LiteralPath $Paths.Samples)) {
        New-Item -ItemType Directory -Force -Path $Paths.Samples | Out-Null
        return
    }

    Get-ChildItem -LiteralPath $Paths.Samples -Force | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force
    }
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

function Build-SampleSummary {
    param(
        [int]$SampleIndex,
        [datetime]$CapturedAt,
        [object]$Diagnostics,
        [string]$DiagnosticsFile,
        [string]$MetricsFile
    )

    $metricsText = [string]$Diagnostics.metrics
    $metricSamples = Parse-MetricSamples -MetricsText $metricsText
    $runtimeLabels = @{ runtime = "client" }
    $session = $Diagnostics.session
    $events = @($Diagnostics.events)
    $challenges = @($Diagnostics.challenges)
    $lastEvent = $null
    if ($events.Count -gt 0) {
        $lastEvent = $events[-1]
    }

    $useDtls = $null
    if ($null -ne $session.profile.use_dtls) {
        $useDtls = [bool]$session.profile.use_dtls
    }

    return [pscustomobject][ordered]@{
        sample_index                 = $SampleIndex
        captured_at                  = $CapturedAt.ToString("o")
        session_id                   = [string]$session.id
        state                        = [string]$session.state
        profile_id                   = [string]$session.profile_id
        provider                     = [string]$session.profile.provider
        listen_addr                  = [string]$session.profile.listen_addr
        peer_addr                    = [string]$session.profile.peer_addr
        mode                         = [string]$session.profile.mode
        connections                  = [int]$session.profile.connections
        use_dtls                     = $useDtls
        event_count                  = $events.Count
        challenge_count              = $challenges.Count
        active_workers               = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_active_workers" -RequiredLabels $runtimeLabels
        session_starts_total         = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_session_starts_total" -RequiredLabels $runtimeLabels
        session_failures_total       = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_session_failures_total" -RequiredLabels $runtimeLabels
        startup_stage_failures_total = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_startup_stage_failures_total" -RequiredLabels $runtimeLabels
        transport_failures_total     = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_transport_stage_failures_total" -RequiredLabels $runtimeLabels
        local_to_relay_packets       = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_forwarded_packets_total" -RequiredLabels @{ runtime = "client"; direction = "local_to_relay" }
        local_to_relay_bytes         = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_forwarded_bytes_total" -RequiredLabels @{ runtime = "client"; direction = "local_to_relay" }
        relay_to_local_packets       = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_forwarded_packets_total" -RequiredLabels @{ runtime = "client"; direction = "relay_to_local" }
        relay_to_local_bytes         = Measure-MetricTotal -MetricSamples $metricSamples -Name "vk_turn_proxy_runtime_forwarded_bytes_total" -RequiredLabels @{ runtime = "client"; direction = "relay_to_local" }
        last_event_type              = if ($null -ne $lastEvent) { [string]$lastEvent.type } else { "" }
        last_event_stage             = if ($null -ne $lastEvent) { [string]$lastEvent.stage } else { "" }
        last_event_state             = if ($null -ne $lastEvent) { [string]$lastEvent.state } else { "" }
        last_event_message           = if ($null -ne $lastEvent) { [string]$lastEvent.message } else { "" }
        diagnostics_file             = $DiagnosticsFile
        metrics_file                 = $MetricsFile
    }
}

function Write-SummaryRow {
    param(
        [string]$CsvPath,
        [string]$NdjsonPath,
        [object]$Summary
    )

    $Summary | ConvertTo-Json -Compress -Depth 8 | Add-Content -Path $NdjsonPath -Encoding utf8
    if (Test-Path $CsvPath) {
        $Summary | Export-Csv -Path $CsvPath -NoTypeInformation -Append
    }
    else {
        $Summary | Export-Csv -Path $CsvPath -NoTypeInformation
    }
}

$script:BaseHostUrl = $HostUrl
$paths = New-OutputPaths
Clear-ManagedOutputArtifacts -Paths $paths
$captureStartedAt = Get-Date
$hostInfo = Get-HostInfo
Assert-RequiredCapabilities -HostInfo $hostInfo
$initialSessions = Get-Sessions
$targetSession = Resolve-TargetSession

Write-JsonFile -Path $paths.Host -Value $hostInfo
Write-JsonFile -Path $paths.Sessions -Value $initialSessions
Write-JsonFile -Path $paths.Manifest -Value ([ordered]@{
    started_at               = $captureStartedAt.ToString("o")
    host_url                 = $HostUrl
    output_dir               = $paths.Root
    requested_session_id     = $SessionId
    requested_profile_id     = $ProfileId
    sample_interval_seconds  = $SampleIntervalSeconds
    duration_seconds         = $DurationSeconds
    wait_for_session_seconds = $WaitForSessionSeconds
    target_session_id        = [string]$targetSession.id
    target_profile_id        = [string]$targetSession.profile_id
    host                     = $hostInfo
})

Write-Host "capture_dir=$($paths.Root)"
Write-Host "session_id=$($targetSession.id)"
Write-Host "profile_id=$($targetSession.profile_id)"

$sampleCount = 0
$errorCount = 0
$deadline = if ($DurationSeconds -eq 0) { [DateTime]::MaxValue } else { (Get-Date).AddSeconds($DurationSeconds) }

while ((Get-Date) -lt $deadline) {
    $sampleCount++
    $capturedAt = Get-Date
    $sampleStamp = $capturedAt.ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
    $prefix = "{0:D4}-$sampleStamp" -f $sampleCount
    $diagnosticsFileName = "$prefix-diagnostics.json"
    $metricsFileName = "$prefix-metrics.prom"
    $diagnosticsPath = Join-Path $paths.Samples $diagnosticsFileName
    $metricsPath = Join-Path $paths.Samples $metricsFileName

    try {
        $diagnostics = Invoke-ControlPlane -Method "GET" -Path "/v1/sessions/$($targetSession.id)/diagnostics"
        Write-JsonFile -Path $diagnosticsPath -Value $diagnostics
        [string]$diagnostics.metrics | Set-Content -Path $metricsPath -Encoding utf8
        Copy-Item -Path $diagnosticsPath -Destination $paths.LatestDiag -Force
        Copy-Item -Path $metricsPath -Destination $paths.LatestMetrics -Force

        $summary = Build-SampleSummary `
            -SampleIndex $sampleCount `
            -CapturedAt $capturedAt `
            -Diagnostics $diagnostics `
            -DiagnosticsFile $diagnosticsFileName `
            -MetricsFile $metricsFileName
        Write-SummaryRow -CsvPath $paths.SummaryCsv -NdjsonPath $paths.SummaryNdjson -Summary $summary

        Write-Host ("sample={0} ts={1} state={2} active_workers={3} tx_bytes={4} rx_bytes={5}" -f `
                $summary.sample_index,
                $summary.captured_at,
                $summary.state,
                $summary.active_workers,
                $summary.local_to_relay_bytes,
                $summary.relay_to_local_bytes)
    }
    catch {
        $errorCount++
        $errorSummary = [pscustomobject][ordered]@{
            sample_index = $sampleCount
            captured_at  = $capturedAt.ToString("o")
            session_id   = [string]$targetSession.id
            error        = $_.Exception.Message
        }
        $errorSummary | ConvertTo-Json -Compress | Add-Content -Path $paths.ErrorsNdjson -Encoding utf8
        Write-Warning $errorSummary.error
    }

    if ($DurationSeconds -ne 0 -and (Get-Date) -ge $deadline) {
        break
    }
    Start-Sleep -Seconds $SampleIntervalSeconds
}

Write-JsonFile -Path $paths.SessionsFinal -Value (Get-Sessions)
Write-JsonFile -Path $paths.Manifest -Value ([ordered]@{
    started_at               = $captureStartedAt.ToString("o")
    host_url                 = $HostUrl
    output_dir               = $paths.Root
    requested_session_id     = $SessionId
    requested_profile_id     = $ProfileId
    sample_interval_seconds  = $SampleIntervalSeconds
    duration_seconds         = $DurationSeconds
    wait_for_session_seconds = $WaitForSessionSeconds
    target_session_id        = [string]$targetSession.id
    target_profile_id        = [string]$targetSession.profile_id
    samples_written          = $sampleCount
    errors_written           = $errorCount
    finished_at              = (Get-Date).ToString("o")
    host                     = $hostInfo
})

Write-Host "samples_written=$sampleCount"
Write-Host "errors_written=$errorCount"
Write-Host "summary_csv=$($paths.SummaryCsv)"
Write-Host "summary_ndjson=$($paths.SummaryNdjson)"
