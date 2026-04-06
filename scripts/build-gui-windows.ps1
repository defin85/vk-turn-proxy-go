param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ClientdPath = "",
    [string]$FlutterVersionFile = ""
)

$ErrorActionPreference = "Stop"

function Assert-WindowsNativePath {
    param(
        [string]$PathValue,
        [string]$Label
    )

    if ($PathValue.StartsWith("\\")) {
        throw "$Label must be a Windows-native path, not a UNC path: $PathValue"
    }
}

function Get-RequiredFlutterVersion {
    param(
        [string]$GuiRoot,
        [string]$VersionFile
    )

    if ([string]::IsNullOrWhiteSpace($VersionFile)) {
        $VersionFile = Join-Path $GuiRoot ".flutter-version"
    }

    if (-not (Test-Path $VersionFile)) {
        throw "Flutter version file not found: $VersionFile"
    }

    return (Get-Content $VersionFile -Raw).Trim()
}

function Invoke-FlutterChecked {
    param(
        [string[]]$Arguments
    )

    & flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "flutter $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
Assert-WindowsNativePath -PathValue $resolvedRepoRoot -Label "RepoRoot"

$guiRoot = Join-Path $resolvedRepoRoot "desktop\gui_shell"
if (-not (Test-Path $guiRoot)) {
    throw "desktop/gui_shell not found under $resolvedRepoRoot"
}

$requiredFlutterVersion = Get-RequiredFlutterVersion -GuiRoot $guiRoot -VersionFile $FlutterVersionFile

if ([string]::IsNullOrWhiteSpace($ClientdPath)) {
    $ClientdPath = Join-Path $resolvedRepoRoot "dist\go\windows-amd64\clientd.exe"
}

$resolvedClientdPath = (Resolve-Path $ClientdPath).Path
Assert-WindowsNativePath -PathValue $resolvedClientdPath -Label "ClientdPath"
Push-Location $resolvedRepoRoot
try {
    $flutterVersionText = (& flutter --version 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "flutter --version failed"
    }

    if ($flutterVersionText -notmatch ("Flutter\s+" + [regex]::Escape($requiredFlutterVersion) + "\b")) {
        throw "Windows Flutter version mismatch. Expected $requiredFlutterVersion based on desktop/gui_shell/.flutter-version."
    }

    $doctorText = (& flutter doctor -v 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "flutter doctor -v failed"
    }
    if ($doctorText -notmatch "\[✓\]\s+Windows Version") {
        throw "flutter doctor -v did not confirm a working Windows host."
    }
    if ($doctorText -notmatch "\[✓\]\s+Visual Studio - develop Windows apps") {
        throw "flutter doctor -v did not confirm the required Visual Studio Windows desktop toolchain."
    }

    Push-Location $guiRoot
    try {
        Invoke-FlutterChecked -Arguments @("pub", "get")
        Invoke-FlutterChecked -Arguments @("build", "windows")
    }
    finally {
        Pop-Location
    }

    $releaseDir = Join-Path $guiRoot "build\windows\x64\runner\Release"
    $guiExePath = Join-Path $releaseDir "gui_shell.exe"
    if (-not (Test-Path $guiExePath)) {
        throw "expected GUI executable not found after build: $guiExePath"
    }

    Copy-Item $resolvedClientdPath (Join-Path $releaseDir "clientd.exe") -Force

    $stageDir = Join-Path $resolvedRepoRoot "dist\windows-gui"
    if (Test-Path $stageDir) {
        Remove-Item $stageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $stageDir | Out-Null
    Copy-Item (Join-Path $releaseDir "*") $stageDir -Recurse -Force

    Write-Host "Staged Windows GUI bundle at $stageDir"
}
finally {
    Pop-Location
}
