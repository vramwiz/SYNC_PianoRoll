$ErrorActionPreference = 'Stop'

$packageName = 'SYNC_PianoRoll'
$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$pluginDir = 'C:\ProgramData\aviutl2\Plugin\SYNC_PianoRoll'
$workDir = Join-Path $PSScriptRoot $packageName
$zipFile = Join-Path $PSScriptRoot "$packageName.zip"

$packageFiles = @(
  @{
    Source = Join-Path $pluginDir 'SYNC_PianoRoll_Input.aui2'
    Destination = 'SYNC_PianoRoll_Input.aui2'
    Description = 'input plugin'
  },
  @{
    Source = Join-Path $pluginDir 'SYNC_PianoRoll_Filter.auf2'
    Destination = 'SYNC_PianoRoll_Filter.auf2'
    Description = 'filter plugin'
  },
  @{
    Source = Join-Path $projectRoot 'Object\1920x1080_30fps.object'
    Destination = 'Object\1920x1080_30fps.object'
    Description = '1920x1080 30fps alias'
  },
  @{
    Source = Join-Path $projectRoot 'Object\1920x1080_60fps.object'
    Destination = 'Object\1920x1080_60fps.object'
    Description = '1920x1080 60fps alias'
  },
  @{
    Source = Join-Path $projectRoot 'Object\1080x1080_30fps.object'
    Destination = 'Object\1080x1080_30fps.object'
    Description = '1080x1080 30fps alias'
  },
  @{
    Source = Join-Path $projectRoot 'Object\1080x1920_30fps.object'
    Destination = 'Object\1080x1920_30fps.object'
    Description = '1080x1920 30fps alias'
  }
)

foreach ($item in $packageFiles) {
  if (-not (Test-Path -LiteralPath $item.Source -PathType Leaf)) {
    Write-Host "$($item.Description) not found:"
    Write-Host "  $($item.Source)"
    Write-Host 'Build the Release configuration first, then run this batch again.'
    exit 1
  }
}

if (Test-Path -LiteralPath $workDir) {
  Remove-Item -LiteralPath $workDir -Recurse -Force
}

if (Test-Path -LiteralPath $zipFile) {
  Remove-Item -LiteralPath $zipFile -Force
}

try {
  New-Item -ItemType Directory -Path $workDir -Force | Out-Null

  foreach ($item in $packageFiles) {
    $destination = Join-Path $workDir $item.Destination
    $destinationDir = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $destinationDir)) {
      New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $item.Source -Destination $destination -Force
  }

  Compress-Archive -Path $workDir -DestinationPath $zipFile -Force
}
finally {
  if (Test-Path -LiteralPath $workDir) {
    Remove-Item -LiteralPath $workDir -Recurse -Force
  }
}

Write-Host 'Created:'
Write-Host "  $zipFile"
