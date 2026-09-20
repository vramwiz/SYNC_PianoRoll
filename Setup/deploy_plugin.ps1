# ビルド成果物を配布名に変換し、起動先へ同じファイルを配置する。
# 使用中のDLLを更新できない場合はビルドを失敗させ、旧版での動作確認を防ぐ。
param(
    [Parameter(Mandatory = $true)][string]$OutputDirectory,
    [string]$PluginDirectory = "$env:ProgramData\aviutl2\Plugin\SYNC_PianoRoll"
)
$ErrorActionPreference = 'Stop'
try {
    $dll = Join-Path $OutputDirectory 'SYNC_PianoRoll_Filter.dll'
    $plugin = Join-Path $OutputDirectory 'SYNC_PianoRoll_Filter.auf2'
    Copy-Item -LiteralPath $dll -Destination $plugin -Force
    [IO.Directory]::CreateDirectory($PluginDirectory) | Out-Null
    Copy-Item -LiteralPath $plugin -Destination (Join-Path $PluginDirectory 'SYNC_PianoRoll_Filter.auf2') -Force
    Write-Host "Plugin deployed: $PluginDirectory"
}
catch {
    Write-Error "プラグインを配置できません。AviUtl2を終了して再ビルドしてください。 $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
