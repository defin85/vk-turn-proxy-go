param(
    [ValidateSet("check", "start", "status", "stop", "diagnostics")]
    [string]$Action = "check",
    [string]$HostUrl = "http://127.0.0.1:7777",
    [string]$ProfileId = "desktop-generic-turn",
    [string]$ProfileName = "Desktop generic TURN",
    [string]$TurnLink = "",
    [string]$ListenAddr = "127.0.0.1:39010",
    [string]$PeerAddr = "176.109.104.105:56040",
    [ValidateSet("auto", "udp", "tcp")]
    [string]$Mode = "udp",
    [int]$Connections = 1,
    [bool]$UseDtls = $true,
    [int]$ReadyTimeoutSeconds = 45,
    [string]$SessionId = "",
    [string]$DiagnosticsPath = "",
    [switch]$ReplaceExisting
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($TurnLink)) {
    $TurnLink = $env:TURN_LINK
}

$requiredCapabilities = @(
    "desktop_sidecar",
    "profiles",
    "sessions",
    "diagnostics"
)

function Invoke-ControlPlane {
    param(
        [string]$Method,
        [string]$Path,
        [object]$Body = $null
    )

    $base = $script:BaseHostUrl.TrimEnd("/")
    $uri = "$base$Path"
    $invokeArgs = @{
        Method      = $Method
        Uri         = $uri
        ContentType = "application/json"
    }
    if ($null -ne $Body) {
        $invokeArgs["Body"] = ($Body | ConvertTo-Json -Depth 8)
    }

    try {
        return Invoke-RestMethod @invokeArgs
    }
    catch {
        $message = $_.Exception.Message
        throw "request failed: $Method $($uri): $message"
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

function Get-ProfileSessions {
    return @(Get-Sessions | Where-Object { $_.profile_id -eq $ProfileId })
}

function Get-LatestProfileSession {
    param(
        [string[]]$AllowedStates = @()
    )

    $sessions = Get-ProfileSessions
    if ($AllowedStates.Count -gt 0) {
        $sessions = @($sessions | Where-Object { $AllowedStates -contains $_.state })
    }
    if ($sessions.Count -eq 0) {
        return $null
    }

    return $sessions |
        Sort-Object `
            @{ Expression = { Get-SortTimestamp $_ }; Descending = $true }, `
            @{ Expression = { $_.id }; Descending = $true } |
        Select-Object -First 1
}

function Write-SessionSummary {
    param(
        [object]$Session
    )

    if ($null -eq $Session) {
        Write-Host "no session"
        return
    }

    $line = "session_id=$($Session.id) state=$($Session.state) profile_id=$($Session.profile_id)"
    if ($Session.failure) {
        $line = "$line stage=$($Session.failure.stage) message=$($Session.failure.message)"
    }
    if (-not [string]::IsNullOrWhiteSpace($Session.active_challenge_id)) {
        $line = "$line active_challenge_id=$($Session.active_challenge_id)"
    }
    Write-Host $line
}

function Wait-SessionReady {
    param(
        [string]$TargetSessionId
    )

    $deadline = (Get-Date).AddSeconds($ReadyTimeoutSeconds)
    while ((Get-Date) -lt $deadline) {
        $session = Invoke-ControlPlane -Method "GET" -Path "/v1/sessions/$TargetSessionId"
        switch ($session.state) {
            "ready" {
                return $session
            }
            "failed" {
                Write-SessionSummary $session
                throw "desktop session failed before ready"
            }
            "stopped" {
                Write-SessionSummary $session
                throw "desktop session stopped before ready"
            }
            "challenge_required" {
                Write-SessionSummary $session
                throw "generic-turn desktop session unexpectedly entered challenge_required"
            }
        }
        Start-Sleep -Milliseconds 500
    }

    throw "desktop session did not reach ready within ${ReadyTimeoutSeconds}s"
}

function Stop-SessionIfNeeded {
    param(
        [object]$Session
    )

    if ($null -eq $Session) {
        return
    }

    Write-Host "stopping existing session $($Session.id)"
    $stopped = Invoke-ControlPlane -Method "POST" -Path "/v1/sessions/$($Session.id)/stop"
    Write-SessionSummary $stopped
}

function Upsert-Profile {
    if ([string]::IsNullOrWhiteSpace($TurnLink)) {
        throw "TURN_LINK or -TurnLink is required"
    }

    $body = @{
        id   = $ProfileId
        name = $ProfileName
        spec = @{
            provider    = "generic-turn"
            link        = $TurnLink
            listen_addr = $ListenAddr
            peer_addr   = $PeerAddr
            connections = $Connections
            mode        = $Mode
            use_dtls    = $UseDtls
            log_level   = "info"
        }
    }

    return Invoke-ControlPlane -Method "POST" -Path "/v1/profiles" -Body $body
}

$script:BaseHostUrl = $HostUrl
$hostInfo = Get-HostInfo
Assert-RequiredCapabilities -HostInfo $hostInfo

switch ($Action) {
    "check" {
        Write-Host "host_version=$($hostInfo.version) contract_version=$($hostInfo.contract_version)"
        Write-Host "capabilities=$(@($hostInfo.capabilities) -join ',')"
        $session = Get-LatestProfileSession
        Write-SessionSummary $session
        break
    }
    "start" {
        if ($ReplaceExisting) {
            $active = Get-LatestProfileSession -AllowedStates @("starting", "challenge_required", "ready", "retrying")
            Stop-SessionIfNeeded $active
        }

        $profile = Upsert-Profile
        Write-Host "profile_id=$($profile.id) provider=$($profile.spec.provider) peer=$($profile.spec.peer_addr)"
        $session = Invoke-ControlPlane -Method "POST" -Path "/v1/sessions" -Body @{
            profile_id = $ProfileId
        }
        Write-SessionSummary $session
        $ready = Wait-SessionReady -TargetSessionId $session.id
        Write-Host "desktop session ready"
        Write-SessionSummary $ready
        break
    }
    "status" {
        $session = $null
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $session = Invoke-ControlPlane -Method "GET" -Path "/v1/sessions/$SessionId"
        }
        else {
            $session = Get-LatestProfileSession
        }
        Write-SessionSummary $session
        break
    }
    "stop" {
        $session = $null
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $session = Invoke-ControlPlane -Method "GET" -Path "/v1/sessions/$SessionId"
        }
        else {
            $session = Get-LatestProfileSession -AllowedStates @("starting", "challenge_required", "ready", "retrying")
        }
        if ($null -eq $session) {
            throw "no active desktop session found for profile_id=$ProfileId"
        }
        $stopped = Invoke-ControlPlane -Method "POST" -Path "/v1/sessions/$($session.id)/stop"
        Write-SessionSummary $stopped
        break
    }
    "diagnostics" {
        $session = $null
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $session = Invoke-ControlPlane -Method "GET" -Path "/v1/sessions/$SessionId"
        }
        else {
            $session = Get-LatestProfileSession
        }
        if ($null -eq $session) {
            throw "no desktop session found for profile_id=$ProfileId"
        }

        $diagnostics = Invoke-ControlPlane -Method "GET" -Path "/v1/sessions/$($session.id)/diagnostics"
        if ([string]::IsNullOrWhiteSpace($DiagnosticsPath)) {
            $DiagnosticsPath = Join-Path $env:TEMP "$ProfileId-$($session.id)-diagnostics.json"
        }
        $directory = Split-Path -Parent $DiagnosticsPath
        if (-not [string]::IsNullOrWhiteSpace($directory)) {
            New-Item -ItemType Directory -Force -Path $directory | Out-Null
        }
        $diagnostics | ConvertTo-Json -Depth 12 | Set-Content -Path $DiagnosticsPath -Encoding utf8
        Write-Host "diagnostics_path=$DiagnosticsPath"
        Write-SessionSummary $session
        break
    }
}
