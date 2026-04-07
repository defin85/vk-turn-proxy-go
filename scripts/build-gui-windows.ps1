param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ClientdPath = "",
    [string]$FlutterVersionFile = "",
    [string]$ProductName = "",
    [string]$ProductVersion = "",
    [string]$BuildNumber = "",
    [string]$Revision = "",
    [string]$Dirty = "",
    [string]$BuiltAt = ""
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

function Get-VersionManifest {
    param(
        [string]$RepoRootPath
    )

    $manifestPath = Join-Path $RepoRootPath "version.json"
    if (-not (Test-Path $manifestPath)) {
        throw "version manifest not found: $manifestPath"
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace($manifest.product)) {
        throw "version manifest missing product"
    }
    if ([string]::IsNullOrWhiteSpace($manifest.version)) {
        throw "version manifest missing version"
    }
    if ($null -eq $manifest.build_number -or [string]::IsNullOrWhiteSpace("$($manifest.build_number)")) {
        throw "version manifest missing build_number"
    }

    return @{
        Product = "$($manifest.product)".Trim()
        Version = "$($manifest.version)".Trim()
        BuildNumber = "$($manifest.build_number)".Trim()
    }
}

function Get-PubspecVersion {
    param(
        [string]$GuiRoot
    )

    $pubspecPath = Join-Path $GuiRoot "pubspec.yaml"
    if (-not (Test-Path $pubspecPath)) {
        throw "pubspec not found: $pubspecPath"
    }

    $content = Get-Content $pubspecPath -Raw
    $match = [regex]::Match($content, "(?m)^version:\s*([^\r\n]+)\s*$")
    if (-not $match.Success) {
        throw "pubspec.yaml missing version"
    }

    return $match.Groups[1].Value.Trim()
}

function Get-GitMetadata {
    param(
        [string]$RepoRootPath
    )

    if (-not (Test-Path (Join-Path $RepoRootPath ".git"))) {
        return @{
            Revision = ""
            Dirty = ""
            BuiltAt = ""
        }
    }

    Push-Location $RepoRootPath
    try {
        $revisionText = (& git rev-parse --short=12 HEAD 2>&1 | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) {
            throw "git rev-parse failed"
        }

        $statusText = (& git status --porcelain --untracked-files=no 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) {
            throw "git status failed"
        }

        return @{
            Revision = $revisionText
            Dirty = $(if ([string]::IsNullOrWhiteSpace($statusText)) { "false" } else { "true" })
            BuiltAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
    }
    finally {
        Pop-Location
    }
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

$manifest = Get-VersionManifest -RepoRootPath $resolvedRepoRoot
if ([string]::IsNullOrWhiteSpace($ProductName)) {
    $ProductName = $manifest.Product
}
if ([string]::IsNullOrWhiteSpace($ProductVersion)) {
    $ProductVersion = $manifest.Version
}
if ([string]::IsNullOrWhiteSpace($BuildNumber)) {
    $BuildNumber = $manifest.BuildNumber
}

$gitMetadata = Get-GitMetadata -RepoRootPath $resolvedRepoRoot
if ([string]::IsNullOrWhiteSpace($Revision)) {
    $Revision = $gitMetadata.Revision
}
if ([string]::IsNullOrWhiteSpace($Dirty)) {
    $Dirty = $gitMetadata.Dirty
}
if ([string]::IsNullOrWhiteSpace($BuiltAt)) {
    $BuiltAt = $gitMetadata.BuiltAt
}
if ([string]::IsNullOrWhiteSpace($Revision)) {
    $Revision = "dev"
}
if ([string]::IsNullOrWhiteSpace($Dirty)) {
    $Dirty = "false"
}
if ([string]::IsNullOrWhiteSpace($BuiltAt)) {
    $BuiltAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

$expectedGuiVersion = "$ProductVersion+$BuildNumber"
$actualGuiVersion = Get-PubspecVersion -GuiRoot $guiRoot
if ($actualGuiVersion -ne $expectedGuiVersion) {
    throw "desktop/gui_shell/pubspec.yaml version mismatch. Expected $expectedGuiVersion based on version.json, found $actualGuiVersion."
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
        Invoke-FlutterChecked -Arguments @(
            "build",
            "windows",
            "--build-name",
            $ProductVersion,
            "--build-number",
            $BuildNumber,
            "--dart-define=VKTP_PRODUCT_NAME=$ProductName",
            "--dart-define=VKTP_PRODUCT_VERSION=$ProductVersion",
            "--dart-define=VKTP_BUILD_NUMBER=$BuildNumber",
            "--dart-define=VKTP_REVISION=$Revision",
            "--dart-define=VKTP_DIRTY=$Dirty",
            "--dart-define=VKTP_BUILT_AT=$BuiltAt",
            "--dart-define=VKTP_ARTIFACT_ROLE=gui_shell",
            "--dart-define=VKTP_ARTIFACT_TARGET=windows/x64"
        )
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
