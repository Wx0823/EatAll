param(
    [string]$Gradle = (Join-Path $PSScriptRoot '../.tools/google-plugin/gradle-8.11.1/bin/gradle.bat'),
    [int]$TimeoutSeconds = 300
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$authRoot = Join-Path $projectRoot 'android-auth'
$env:JAVA_HOME = Join-Path $projectRoot '.tools/java/jdk-17.0.20.1+1'
$env:ANDROID_HOME = Join-Path $projectRoot '.tools/android-sdk'
$env:GRADLE_USER_HOME = Join-Path $projectRoot '.tools/google-plugin/gradle-cache'
if (-not (Test-Path -LiteralPath $Gradle)) { throw 'Install Gradle 8.11.1 or pass -Gradle. No downloads are hidden in this script.' }
if (-not (Test-Path -LiteralPath $env:JAVA_HOME)) { throw 'JDK 17 is required.' }
$logDir = Join-Path $projectRoot '.tools/google-plugin'
New-Item -ItemType Directory -Force $logDir | Out-Null
$buildArgs = @('--no-daemon', '--console=plain', '-p', $authRoot, 'assembleRelease')
$compileJar = Join-Path $logDir 'godot-classes.jar'
if (Test-Path -LiteralPath $compileJar) { $buildArgs += "-PgodotCompileJar=$compileJar" }
# This repository path has no spaces. Quote for other checkout paths before passing to cmd.
$quotedArgs = $buildArgs | ForEach-Object { '"' + $_.Replace('"', '') + '"' }
$process = Start-Process -FilePath $Gradle -ArgumentList $quotedArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDir 'build.stdout.txt') -RedirectStandardError (Join-Path $logDir 'build.stderr.txt')
# Cache the handle before waiting; Windows PowerShell otherwise can return a null ExitCode.
$process.Handle | Out-Null
if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
    & taskkill.exe /PID $process.Id /T /F | Out-Null
    throw "Google plugin build exceeded $TimeoutSeconds seconds; see .tools/google-plugin/build.stdout.txt"
}
if ($process.ExitCode -ne 0) { throw 'Google plugin build failed; see .tools/google-plugin/build.stdout.txt and build.stderr.txt' }
$output = Join-Path $projectRoot 'game/addons/eatall_google/bin'
New-Item -ItemType Directory -Force $output | Out-Null
Copy-Item -LiteralPath (Join-Path $authRoot 'build/outputs/aar/EatAllGoogle-release.aar') -Destination (Join-Path $output 'EatAllGoogle.aar') -Force
Get-FileHash -LiteralPath (Join-Path $output 'EatAllGoogle.aar') -Algorithm SHA256
