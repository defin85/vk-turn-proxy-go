param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$ProductName = "",
    [string]$ProductVersion = "",
    [string]$BuildNumber = "",
    [string]$Revision = "",
    [string]$Dirty = "",
    [string]$BuiltAt = "",
    [string]$AndroidApiLevel = "21"
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

function Get-BuildMetadataFromFile {
    param(
        [string]$RepoRootPath
    )

    $metadataPath = Join-Path $RepoRootPath "dist\build\android-embedded-host-build-metadata.json"
    if (-not (Test-Path $metadataPath)) {
        return $null
    }

    $metadata = Get-Content $metadataPath -Raw | ConvertFrom-Json
    return @{
        Product = "$($metadata.product)".Trim()
        Version = "$($metadata.version)".Trim()
        BuildNumber = "$($metadata.build_number)".Trim()
        Revision = "$($metadata.revision)".Trim()
        Dirty = $(if ($metadata.dirty) { "true" } else { "false" })
        BuiltAt = "$($metadata.built_at)".Trim()
        Role = "$($metadata.role)".Trim()
        Target = "$($metadata.target)".Trim()
    }
}

function Get-NdkRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_NDK_HOME) -and (Test-Path $env:ANDROID_NDK_HOME)) {
        return (Resolve-Path $env:ANDROID_NDK_HOME).Path
    }

    $sdkRoot = $env:ANDROID_SDK_ROOT
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        $sdkRoot = $env:ANDROID_HOME
    }
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        $sdkRoot = "C:\Users\Egor\AppData\Local\Android\Sdk"
    }
    if (-not (Test-Path $sdkRoot)) {
        throw "Android SDK root not found: $sdkRoot"
    }

    $ndkRoot = Join-Path $sdkRoot "ndk"
    if (-not (Test-Path $ndkRoot)) {
        throw "Android NDK root not found under $ndkRoot"
    }

    $latest = Get-ChildItem -Path $ndkRoot -Directory | Sort-Object Name | Select-Object -Last 1
    if ($null -eq $latest) {
        throw "Android NDK versions not found under $ndkRoot"
    }

    return $latest.FullName
}

function Invoke-GoBuild {
    param(
        [string]$RepoRootPath,
        [string]$OutputLib,
        [string]$GoArch,
        [string]$CcPath,
        [string]$ArtifactTarget,
        [hashtable]$ExtraEnvironment
    )

    $goExe = (Get-Command go.exe -ErrorAction Stop).Source
    $env:CGO_ENABLED = "1"
    $env:GOOS = "android"
    $env:GOARCH = $GoArch
    $env:CC = $CcPath
    Remove-Item Env:GOARM -ErrorAction SilentlyContinue
    if ($null -ne $ExtraEnvironment) {
        foreach ($key in $ExtraEnvironment.Keys) {
            Set-Item -Path "Env:$key" -Value "$($ExtraEnvironment[$key])"
        }
    }

    $ldflags = @(
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ProductName=$ProductName",
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ProductVersion=$ProductVersion",
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.BuildNumber=$BuildNumber",
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.Revision=$Revision",
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.Dirty=$Dirty",
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.BuiltAt=$BuiltAt",
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ArtifactRole=android_embedded_host",
        "-X github.com/defin85/vk-turn-proxy-go/internal/buildinfo.ArtifactTarget=$ArtifactTarget"
    ) -join " "

    Push-Location $RepoRootPath
    try {
        & $goExe build -trimpath -buildmode=c-shared -ldflags $ldflags -o $OutputLib .\cmd\android-mobile-host
        if ($LASTEXITCODE -ne 0) {
            throw "go build failed for $ArtifactTarget"
        }
    }
    finally {
        Pop-Location
        Remove-Item Env:CGO_ENABLED -ErrorAction SilentlyContinue
        Remove-Item Env:GOOS -ErrorAction SilentlyContinue
        Remove-Item Env:GOARCH -ErrorAction SilentlyContinue
        Remove-Item Env:CC -ErrorAction SilentlyContinue
        Remove-Item Env:GOARM -ErrorAction SilentlyContinue
    }
}

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
Assert-WindowsNativePath -PathValue $resolvedRepoRoot -Label "RepoRoot"

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

$buildMetadata = Get-BuildMetadataFromFile -RepoRootPath $resolvedRepoRoot
if ($null -ne $buildMetadata) {
    if ([string]::IsNullOrWhiteSpace($ProductName)) {
        $ProductName = $buildMetadata.Product
    }
    if ([string]::IsNullOrWhiteSpace($ProductVersion)) {
        $ProductVersion = $buildMetadata.Version
    }
    if ([string]::IsNullOrWhiteSpace($BuildNumber)) {
        $BuildNumber = $buildMetadata.BuildNumber
    }
    if ([string]::IsNullOrWhiteSpace($Revision)) {
        $Revision = $buildMetadata.Revision
    }
    if ([string]::IsNullOrWhiteSpace($Dirty)) {
        $Dirty = $buildMetadata.Dirty
    }
    if ([string]::IsNullOrWhiteSpace($BuiltAt)) {
        $BuiltAt = $buildMetadata.BuiltAt
    }
}

if ($ProductName -ne $manifest.Product -or $ProductVersion -ne $manifest.Version -or $BuildNumber -ne $manifest.BuildNumber) {
    throw "build metadata does not match version.json"
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

$ndkRoot = Get-NdkRoot
$toolchainRoot = Join-Path $ndkRoot "toolchains\llvm\prebuilt\windows-x86_64\bin"
if (-not (Test-Path $toolchainRoot)) {
    throw "expected Android LLVM toolchain under $toolchainRoot"
}

$outputRoot = Join-Path $resolvedRepoRoot "dist\mobile\android-embedded-host"
$jniLibsRoot = Join-Path $outputRoot "jniLibs"
$includeRoot = Join-Path $outputRoot "include"
if (Test-Path $outputRoot) {
    Remove-Item -Recurse -Force $outputRoot
}
New-Item -ItemType Directory -Force -Path $jniLibsRoot | Out-Null
New-Item -ItemType Directory -Force -Path $includeRoot | Out-Null

$targets = @(
    @{
        Abi = "arm64-v8a"
        GoArch = "arm64"
        Compiler = Join-Path $toolchainRoot "aarch64-linux-android$AndroidApiLevel-clang.cmd"
        ArtifactTarget = "android/arm64"
        ExtraEnvironment = @{}
    },
    @{
        Abi = "armeabi-v7a"
        GoArch = "arm"
        Compiler = Join-Path $toolchainRoot "armv7a-linux-androideabi$AndroidApiLevel-clang.cmd"
        ArtifactTarget = "android/arm"
        ExtraEnvironment = @{ GOARM = "7" }
    },
    @{
        Abi = "x86_64"
        GoArch = "amd64"
        Compiler = Join-Path $toolchainRoot "x86_64-linux-android$AndroidApiLevel-clang.cmd"
        ArtifactTarget = "android/amd64"
        ExtraEnvironment = @{}
    }
)

foreach ($target in $targets) {
    if (-not (Test-Path $target.Compiler)) {
        throw "expected Android compiler not found: $($target.Compiler)"
    }

    $abiDir = Join-Path $jniLibsRoot $target.Abi
    New-Item -ItemType Directory -Force -Path $abiDir | Out-Null
    $outputLib = Join-Path $abiDir "libvk_turn_mobile_host.so"

    Invoke-GoBuild `
        -RepoRootPath $resolvedRepoRoot `
        -OutputLib $outputLib `
        -GoArch $target.GoArch `
        -CcPath $target.Compiler `
        -ArtifactTarget $target.ArtifactTarget `
        -ExtraEnvironment $target.ExtraEnvironment

    $generatedHeader = Join-Path $abiDir "libvk_turn_mobile_host.h"
    if (-not (Test-Path $generatedHeader)) {
        throw "generated header missing: $generatedHeader"
    }
    Copy-Item $generatedHeader (Join-Path $includeRoot "android_mobile_host.h") -Force
}

Write-Host "Staged Android embedded host under $outputRoot"
