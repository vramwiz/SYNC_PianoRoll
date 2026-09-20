# 現行Release成果物だけを一時フォルダーへ集め、旧名の統合DLLだけを含むZIPを作る。
$ErrorActionPreference = 'Stop'
$packageName = 'SYNC_PianoRoll'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pluginFile = Join-Path $projectRoot 'Win64\Release\SYNC_PianoRoll_Filter.auf2'
$zipFile = Join-Path $PSScriptRoot "$packageName.zip"
if (-not (Test-Path -LiteralPath $pluginFile -PathType Leaf)) {
  throw "Build SYNC_PianoRoll_Filter.dproj Release Win64 first: $pluginFile"
}
# 毎回固有の作業領域を作り、利用者の同名フォルダーを削除しない。
$workRoot = Join-Path $PSScriptRoot ('.package-' + [guid]::NewGuid().ToString('N'))
$packageDir = Join-Path $workRoot $packageName
New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
try {
  Copy-Item -LiteralPath $pluginFile -Destination $packageDir
  Copy-Item -LiteralPath (Join-Path $projectRoot 'README.md') -Destination $packageDir
  Compress-Archive -LiteralPath $packageDir -DestinationPath $zipFile -Force
}
finally {
  # 再帰削除は今回生成したSetup直下の領域に限定する。
  $resolvedWork = (Resolve-Path -LiteralPath $workRoot).Path
  $resolvedSetup = (Resolve-Path -LiteralPath $PSScriptRoot).Path
  if ((Split-Path -Parent $resolvedWork) -ne $resolvedSetup -or
      (Split-Path -Leaf $resolvedWork) -notlike '.package-*') {
    throw "Unsafe cleanup path: $resolvedWork"
  }
  Remove-Item -LiteralPath $resolvedWork -Recurse -Force
}
Write-Host "Created: $zipFile"
