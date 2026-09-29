param(
    [ValidateSet('All', 'Android', 'Windows')][string]$Target = 'All',
    [string]$Godot = (Join-Path $PSScriptRoot '../.tools/godot_console.exe')
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$gameDir = Join-Path $projectRoot 'game'
$outputDir = Join-Path $projectRoot 'dist'
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot 4.5.1 console executable not found; pass -Godot.' }
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
& $Godot --headless --path $gameDir --import
if ($LASTEXITCODE -ne 0) { throw 'Godot resource import failed.' }
if ($Target -in @('All', 'Android')) {
    & $Godot --headless --path $gameDir --export-debug Android (Join-Path $outputDir 'EatAll-0.1.0-android.apk')
    if ($LASTEXITCODE -ne 0) { throw 'Android export failed. Verify SDK/JDK and matching templates in editor settings.' }
}
if ($Target -in @('All', 'Windows')) {
    & $Godot --headless --path $gameDir --export-release Windows (Join-Path $outputDir 'EatAll-0.1.0-windows.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed.' }
}
Get-ChildItem -LiteralPath $outputDir -File | Where-Object { $_.Extension -in @('.apk', '.exe') } | Get-FileHash -Algorithm SHA256
