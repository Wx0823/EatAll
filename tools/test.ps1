param([string]$Godot = (Join-Path $PSScriptRoot '../.tools/godot_console.exe'))
$ErrorActionPreference = 'Stop'
$gameDir = (Resolve-Path (Join-Path $PSScriptRoot '../game')).Path
& $Godot --headless --path $gameDir --import
if ($LASTEXITCODE -ne 0) { throw 'Import failed.' }
foreach ($suite in @('test_rules', 'test_independent', 'test_ui', 'test_motion', 'test_responsiveness', 'test_fall_food')) {
    & $Godot --headless --path $gameDir --script "res://tests/$suite.gd"
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $suite" }
}
