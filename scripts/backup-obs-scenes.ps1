<#
.SYNOPSIS
    Backs up the OBS scene collection with a timestamp,
    keeps the last 20 backups, and removes older ones.
#>

. "$env:USERPROFILE\Streaming\config.ps1"

$source = "$env:APPDATA\obs-studio\basic\scenes\$SceneCollectionName.json"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$dest = "$Backups_Dir\$SceneCollectionName-$timestamp.json"

if (-not (Test-Path $Backups_Dir)) {
    New-Item -ItemType Directory -Path $Backups_Dir -Force | Out-Null
}

if (-not (Test-Path $source)) {
    Write-Error "Scene collection not found: $source"
    exit 1
}

Copy-Item $source $dest -Force
Write-Output "Backup saved: $dest"

$oldBackups = Get-ChildItem "$Backups_Dir\$SceneCollectionName-*.json" | Sort-Object Name -Descending | Select-Object -Skip 20
foreach ($old in $oldBackups) {
    Remove-Item $old.FullName -Force
    Write-Output "Removed old backup: $($old.Name)"
}

Write-Output "Backup complete. $(@(Get-ChildItem "$Backups_Dir\$SceneCollectionName-*.json").Count) backups retained."
