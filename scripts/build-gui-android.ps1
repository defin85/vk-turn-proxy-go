param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
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

function Get-PublishIdentityManifest {
    param(
        [string]$RepoRootPath
    )

    $manifestPath = Join-Path $RepoRootPath "publish_identity.json"
    if (-not (Test-Path $manifestPath)) {
        throw "publish identity manifest not found: $manifestPath"
    }

    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace("$($manifest.android.application_id)")) {
        throw "publish identity manifest missing android.application_id"
    }
    if ([string]::IsNullOrWhiteSpace("$($manifest.android.namespace)")) {
        throw "publish identity manifest missing android.namespace"
    }
    if ([string]::IsNullOrWhiteSpace("$($manifest.android.kotlin_package)")) {
        throw "publish identity manifest missing android.kotlin_package"
    }

    return @{
        ApplicationId = "$($manifest.android.application_id)".Trim()
        Namespace = "$($manifest.android.namespace)".Trim()
        KotlinPackage = "$($manifest.android.kotlin_package)".Trim()
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

function Sync-AndroidPublishIdentityAssets {
    param(
        [string]$RepoRootPath,
        [hashtable]$Manifest
    )

    $gradlePath = Join-Path $RepoRootPath "mobile\gui_shell\android\app\build.gradle.kts"
    if (-not (Test-Path $gradlePath)) {
        throw "Android build.gradle.kts not found: $gradlePath"
    }

    $gradleContent = Get-Content $gradlePath -Raw
    $updatedGradle = [regex]::Replace(
        $gradleContent,
        '(?m)^(\s*namespace\s*=\s*")[^"]+("\s*)$',
        ('$1' + $Manifest.Namespace + '$2'),
        1
    )
    if ($updatedGradle -eq $gradleContent -and $gradleContent -notmatch [regex]::Escape($Manifest.Namespace)) {
        throw "Android namespace line not found in $gradlePath"
    }
    $updatedGradle = [regex]::Replace(
        $updatedGradle,
        '(?m)^(\s*applicationId\s*=\s*")[^"]+("\s*)$',
        ('$1' + $Manifest.ApplicationId + '$2'),
        1
    )
    if ($updatedGradle -eq $gradleContent -and $gradleContent -notmatch [regex]::Escape($Manifest.ApplicationId)) {
        throw "Android applicationId line not found in $gradlePath"
    }
    Set-Content -Path $gradlePath -Value $updatedGradle -NoNewline

    $kotlinRoot = Join-Path $RepoRootPath "mobile\gui_shell\android\app\src\main\kotlin"
    if (-not (Test-Path $kotlinRoot)) {
        throw "Android Kotlin source root not found: $kotlinRoot"
    }

    $packagePath = $Manifest.KotlinPackage -replace '\.', '\'
    $targetPackageDir = Join-Path $kotlinRoot $packagePath
    New-Item -ItemType Directory -Force -Path $targetPackageDir | Out-Null

    $kotlinFiles = Get-ChildItem -Path $kotlinRoot -Filter *.kt -Recurse -File
    if ($kotlinFiles.Count -eq 0) {
        throw "No Android Kotlin sources found under $kotlinRoot"
    }

    foreach ($file in $kotlinFiles) {
        $content = Get-Content $file.FullName -Raw
        $updated = [regex]::Replace(
            $content,
            '(?m)^package\s+[^\r\n]+$',
            "package $($Manifest.KotlinPackage)",
            1
        )
        if ($updated -eq $content -and $content -notmatch ("(?m)^package\s+" + [regex]::Escape($Manifest.KotlinPackage) + "$")) {
            throw "Android Kotlin package declaration not found in $($file.FullName)"
        }

        $destination = Join-Path $targetPackageDir $file.Name
        if ($file.FullName -ieq $destination) {
            Set-Content -Path $file.FullName -Value $updated -NoNewline
            continue
        }

        Set-Content -Path $destination -Value $updated -NoNewline
        Remove-Item $file.FullName -Force
    }

    Get-ChildItem -Path $kotlinRoot -Directory -Recurse |
        Sort-Object FullName -Descending |
        ForEach-Object {
            if (-not (Get-ChildItem -Path $_.FullName -Force | Select-Object -First 1)) {
                Remove-Item $_.FullName -Force
            }
        }
}

function Sync-GuiVersionAssets {
    param(
        [string]$RepoRootPath,
        [hashtable]$Manifest
    )

    $expectedVersion = "$($Manifest.Version)+$($Manifest.BuildNumber)"
    $pubspecPath = Join-Path $RepoRootPath "mobile\gui_shell\pubspec.yaml"
    if (-not (Test-Path $pubspecPath)) {
        throw "pubspec not found: $pubspecPath"
    }

    $pubspecContent = Get-Content $pubspecPath -Raw
    $updatedPubspec = [regex]::Replace(
        $pubspecContent,
        "(?m)^version:\s*[^\r\n]+\s*$",
        "version: $expectedVersion",
        1
    )
    if ($updatedPubspec -eq $pubspecContent) {
        if ((Get-PubspecVersion -GuiRoot (Join-Path $RepoRootPath "mobile\gui_shell")) -ne $expectedVersion) {
            throw "mobile/gui_shell/pubspec.yaml missing replaceable version line"
        }
    } else {
        Set-Content -Path $pubspecPath -Value $updatedPubspec -NoNewline
    }

    $defaultsPath = Join-Path $RepoRootPath "mobile\gui_shell\lib\src\build\version_defaults.g.dart"
    $defaultsContent = @"
// Generated by scripts/sync-version-assets.py. Do not edit by hand.
const String kVersionManifestProduct = '$($Manifest.Product)';
const String kVersionManifestVersion = '$($Manifest.Version)';
const String kVersionManifestBuildNumber = '$($Manifest.BuildNumber)';
"@
    $defaultsDir = Split-Path $defaultsPath -Parent
    New-Item -ItemType Directory -Force -Path $defaultsDir | Out-Null
    Set-Content -Path $defaultsPath -Value $defaultsContent -NoNewline
}

function Get-BuildMetadataFromFile {
    param(
        [string]$RepoRootPath
    )

    $metadataPath = Join-Path $RepoRootPath "dist\build\android-gui-build-metadata.json"
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

function Get-AndroidSdkRoot {
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_SDK_ROOT) -and (Test-Path $env:ANDROID_SDK_ROOT)) {
        return (Resolve-Path $env:ANDROID_SDK_ROOT).Path
    }
    if (-not [string]::IsNullOrWhiteSpace($env:ANDROID_HOME) -and (Test-Path $env:ANDROID_HOME)) {
        return (Resolve-Path $env:ANDROID_HOME).Path
    }

    $defaultSdkRoot = "C:\Users\Egor\AppData\Local\Android\Sdk"
    if (-not (Test-Path $defaultSdkRoot)) {
        throw "Android SDK root not found: $defaultSdkRoot"
    }
    return $defaultSdkRoot
}

function Get-FlutterSdkRoot {
    $flutterCommand = (Get-Command flutter.bat -ErrorAction Stop).Source
    $binDir = Split-Path $flutterCommand -Parent
    return (Resolve-Path (Join-Path $binDir "..")).Path
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

function Invoke-DartChecked {
    param(
        [string[]]$Arguments
    )

    & dart @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "dart $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
    }
}

function Write-AndroidLocalProperties {
    param(
        [string]$AndroidRoot,
        [string]$AndroidSdkRoot,
        [string]$FlutterSdkRoot
    )

    $localPropertiesPath = Join-Path $AndroidRoot "local.properties"
    $content = @(
        "sdk.dir=$AndroidSdkRoot"
        "flutter.sdk=$FlutterSdkRoot"
    ) -join "`r`n"
    Set-Content -Path $localPropertiesPath -Value $content -NoNewline
}

function Assert-ApkContainsEmbeddedHost {
    param(
        [string]$ApkPath
    )

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $expectedEntries = @(
        "lib/arm64-v8a/libandroid_mobile_host_jni.so"
        "lib/arm64-v8a/libvk_turn_mobile_host.so"
        "lib/armeabi-v7a/libandroid_mobile_host_jni.so"
        "lib/armeabi-v7a/libvk_turn_mobile_host.so"
        "lib/x86_64/libandroid_mobile_host_jni.so"
        "lib/x86_64/libvk_turn_mobile_host.so"
    )

    $archive = [System.IO.Compression.ZipFile]::OpenRead($ApkPath)
    try {
        $entryNames = @($archive.Entries | ForEach-Object { $_.FullName })
        foreach ($expectedEntry in $expectedEntries) {
            if (-not ($entryNames -contains $expectedEntry)) {
                throw "expected APK entry not found: $expectedEntry"
            }
        }
    }
    finally {
        $archive.Dispose()
    }
}

$resolvedRepoRoot = (Resolve-Path $RepoRoot).Path
Assert-WindowsNativePath -PathValue $resolvedRepoRoot -Label "RepoRoot"

$guiRoot = Join-Path $resolvedRepoRoot "mobile\gui_shell"
if (-not (Test-Path $guiRoot)) {
    throw "mobile/gui_shell not found under $resolvedRepoRoot"
}

$publishIdentity = Get-PublishIdentityManifest -RepoRootPath $resolvedRepoRoot
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

Sync-AndroidPublishIdentityAssets -RepoRootPath $resolvedRepoRoot -Manifest $publishIdentity
Sync-GuiVersionAssets -RepoRootPath $resolvedRepoRoot -Manifest $manifest

$expectedGuiVersion = "$ProductVersion+$BuildNumber"
$actualGuiVersion = Get-PubspecVersion -GuiRoot $guiRoot
if ($actualGuiVersion -ne $expectedGuiVersion) {
    throw "mobile/gui_shell/pubspec.yaml version mismatch. Expected $expectedGuiVersion based on version.json, found $actualGuiVersion."
}

$requiredFlutterVersion = Get-RequiredFlutterVersion -GuiRoot $guiRoot -VersionFile $FlutterVersionFile
$androidRoot = Join-Path $guiRoot "android"
$androidSdkRoot = Get-AndroidSdkRoot

Push-Location $resolvedRepoRoot
try {
    $flutterVersionText = (& flutter --version 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "flutter --version failed"
    }
    if ($flutterVersionText -notmatch ("Flutter\s+" + [regex]::Escape($requiredFlutterVersion) + "\b")) {
        throw "Windows Flutter version mismatch. Expected $requiredFlutterVersion based on mobile/gui_shell/.flutter-version."
    }

    $doctorText = (& flutter doctor -v 2>&1 | Out-String)
    if ($LASTEXITCODE -ne 0) {
        throw "flutter doctor -v failed"
    }
    if ($doctorText -notmatch "\[✓\]\s+Android toolchain - develop for Android devices") {
        throw "flutter doctor -v did not confirm the required Android toolchain."
    }

    Invoke-DartChecked -Arguments @("pub", "get")
    Invoke-DartChecked -Arguments @("pub", "workspace", "list")

    $flutterSdkRoot = Get-FlutterSdkRoot
    Write-AndroidLocalProperties -AndroidRoot $androidRoot -AndroidSdkRoot $androidSdkRoot -FlutterSdkRoot $flutterSdkRoot

    $embeddedHostScript = Join-Path $resolvedRepoRoot "scripts\build-android-embedded-host.ps1"
    & $embeddedHostScript `
        -RepoRoot $resolvedRepoRoot `
        -ProductName $ProductName `
        -ProductVersion $ProductVersion `
        -BuildNumber $BuildNumber `
        -Revision $Revision `
        -Dirty $Dirty `
        -BuiltAt $BuiltAt
    if ($LASTEXITCODE -ne 0) {
        throw "build-android-embedded-host.ps1 failed with exit code $LASTEXITCODE"
    }

    Push-Location $guiRoot
    try {
        Invoke-FlutterChecked -Arguments @(
            "build",
            "apk",
            "--debug",
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
            "--dart-define=VKTP_ARTIFACT_ROLE=mobile_gui_shell",
            "--dart-define=VKTP_ARTIFACT_TARGET=android/debug"
        )
    }
    finally {
        Pop-Location
    }

    $apkPath = Join-Path $guiRoot "build\app\outputs\flutter-apk\app-debug.apk"
    if (-not (Test-Path $apkPath)) {
        throw "expected Android APK not found after build: $apkPath"
    }

    Assert-ApkContainsEmbeddedHost -ApkPath $apkPath

    $stageDir = Join-Path $resolvedRepoRoot "dist\mobile\android-gui-shell"
    if (Test-Path $stageDir) {
        Remove-Item $stageDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $stageDir | Out-Null

    Copy-Item $apkPath (Join-Path $stageDir "app-debug.apk") -Force
    $apkShaPath = "$apkPath.sha1"
    if (Test-Path $apkShaPath) {
        Copy-Item $apkShaPath (Join-Path $stageDir "app-debug.apk.sha1") -Force
    }

    $stageMetadata = @{
        product = $ProductName
        version = $ProductVersion
        build_number = $BuildNumber
        revision = $Revision
        dirty = ($Dirty -eq "true")
        built_at = $BuiltAt
        role = "mobile_gui_shell"
        target = "android/debug"
    } | ConvertTo-Json -Depth 3
    Set-Content -Path (Join-Path $stageDir "build-metadata.json") -Value ($stageMetadata + "`n") -NoNewline

    Write-Host "Staged Android GUI APK at $stageDir"
}
finally {
    Pop-Location
}
