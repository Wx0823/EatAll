param(
    [ValidateSet('All', 'Android', 'Windows')][string]$Target = 'All',
    [string]$Godot = (Join-Path $PSScriptRoot '../.tools/godot_console.exe')
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$gameDir = Join-Path $projectRoot 'game'
$projectText = Get-Content (Join-Path $gameDir 'project.godot') -Raw
if ($projectText -notmatch 'config/version="([0-9]+\.[0-9]+\.[0-9]+)"') { throw 'Missing semantic project version.' }
$gameVersion = $Matches[1]
$outputDir = Join-Path $projectRoot 'dist'
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot 4.5.1 console executable not found; pass -Godot.' }
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
if ($Target -in @('All', 'Android')) {
    if (-not (Test-Path -LiteralPath (Join-Path $gameDir 'android/build/build.gradle'))) {
        throw 'Install matching Godot 4.5.1 Android build template first; see design/technical/google-login.md.'
    }
    $env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools/google-plugin/gradle-cache'
    # On Windows a surviving Gradle daemon can retain the console wrapper's
    # inherited output handle after Godot exits, leaving the build waiting.
    $env:GRADLE_OPTS = ($env:GRADLE_OPTS + ' -Dorg.gradle.daemon=false').Trim()
    & (Join-Path $PSScriptRoot 'build_google_plugin.ps1')
    if (-not (Test-Path -LiteralPath (Join-Path $gameDir 'addons/eatall_google/bin/EatAllGoogle.aar'))) {
        throw 'Google native plugin AAR is missing.'
    }
}
& $Godot --headless --path $gameDir --import
if ($LASTEXITCODE -ne 0) { throw 'Godot resource import failed.' }
if ($Target -in @('All', 'Android')) {
    & $Godot --headless --path $gameDir --export-debug Android (Join-Path $outputDir "EatAll-$gameVersion-android.apk")
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed. Verify SDK/JDK and matching templates in editor settings.' }
}
if ($Target -in @('All', 'Windows')) {
    & $Godot --headless --path $gameDir --export-release Windows (Join-Path $outputDir "EatAll-$gameVersion-windows.exe")
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
}
Get-ChildItem -LiteralPath $outputDir -File | Where-Object { $_.Name -like "EatAll-$gameVersion-*" -and $_.Extension -in @('.apk', '.exe') } | Get-FileHash -Algorithm SHA256
