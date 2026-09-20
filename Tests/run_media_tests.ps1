param(
  [ValidateSet('Debug', 'Release')][string]$Config = 'Debug',
  [string]$Compiler = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe'
)
# 単体メディアのDLL契約と共通描画の回帰テストを実行する。削除した旧接続方式は対象外。
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$outputDir = Join-Path $projectRoot "Win64\$Config\Tests"
$pluginPath = Join-Path $projectRoot "Win64\$Config\SYNC_PianoRoll_Filter.auf2"
if (-not (Test-Path -LiteralPath $pluginPath)) { throw "Build $Config first: $pluginPath" }
New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
$unitDirs = @((Join-Path $projectRoot 'Source')) + @(
  Get-ChildItem -LiteralPath (Join-Path $projectRoot 'Source') -Directory -Recurse |
    Select-Object -ExpandProperty FullName
)
$tests = @(
  'SYNC_PianoRoll_MusicDataTests', 'SYNC_PianoRoll_PianoKeyTests',
  'SYNC_PianoRoll_ColorTests', 'SYNC_PianoRoll_PitchFollowTests',
  'SYNC_PianoRoll_RenderTests', 'SYNC_PianoRoll_HorizontalRenderTests',
  'SYNC_PianoRoll_Perspective3DTests', 'SYNC_PianoRoll_Circular3DTests',
  'Media\SYNC_PianoRoll_MediaLoadTests', 'Media\SYNC_PianoRoll_MediaSettingsTests',
  'Media\SYNC_PianoRoll_MediaTimeTests'
)
Push-Location $projectRoot
try {
  foreach ($test in $tests) {
    $compilerArgs = @('-B', '-Q', "-E$outputDir", "-NU$outputDir",
      "-U$($unitDirs -join ';')", '-NSSystem;Xml;Data;Winapi;Vcl', "Tests\$test.dpr")
    & $Compiler @compilerArgs
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $test" }
    $exePath = Join-Path $outputDir "$([IO.Path]::GetFileName($test)).exe"
    if ($test -match 'Media(Load|Settings)Tests$') { & $exePath $pluginPath }
    else { & $exePath }
    if ($LASTEXITCODE -ne 0) { throw "Test failed: $test" }
    Write-Host "PASS $test"
  }
}
finally { Pop-Location }
