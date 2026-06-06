<#
.SYNOPSIS
    Graceful end-of-stream cleanup. Stops all background daemons,
    optionally sends stop-recording to OBS, and removes transient data.

    Usage:
        .\end-stream.ps1              (default: stop jobs + cleanup + OBS stop)
        .\end-stream.ps1 -NoStopRecording  (skip OBS stop-recording)
        .\end-stream.ps1 -NoSceneSwitch    (skip switching to End of Stream scene)
        .\end-stream.ps1 -KeepData         (keep chat-data.json and alerts-queue.json)
#>

param(
    [switch]$NoStopRecording,
    [switch]$NoSceneSwitch,
    [switch]$KeepData
)

$scriptRoot = "$env:USERPROFILE\Streaming"
. "$scriptRoot\config.ps1"

function Write-Step($msg)   { Write-Host "  >> $msg" -ForegroundColor Yellow }
function Write-Ok($msg)     { Write-Host "  [+] $msg" -ForegroundColor Green }
function Write-Info($l,$v)  { Write-Host "  $($l.PadRight(22)) $v" -ForegroundColor Gray }

Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host "       END STREAM                        " -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""

Write-Step "Stopping background daemons..."
$jobNames = @("StreamMonitor", "SpotifyPoller", "AudioVis", "TwitchChat", "HotkeyDaemon", "TimerSceneSwitch")
$stopped = 0
foreach ($name in $jobNames) {
    $job = Get-Job -Name $name -ErrorAction SilentlyContinue
    if ($job) {
        $null = $job | Stop-Job -Force -ErrorAction SilentlyContinue
        $null = $job | Receive-Job -ErrorAction SilentlyContinue
        $job | Remove-Job -Force -ErrorAction SilentlyContinue
        Write-Info "Stopped" "$name"
        $stopped++
    }
}
Write-Ok "Stopped $stopped background job(s)"

if (-not $NoStopRecording -or -not $NoSceneSwitch) {
    Write-Step "Connecting to OBS WebSocket..."
    $wsModule = "$env:USERPROFILE\.config\opencode\modules\obs\scripts\obs-wsapi.psm1"
    if (Test-Path $wsModule) {
        Import-Module $wsModule -Force -ErrorAction SilentlyContinue
        try {
            $ws = Connect-ObsWebSocket -Host $OBS_Host -Port $OBS_Port -Password $OBS_Password
            if (-not $ws) {
                Write-Host "  [!] Could not connect to OBS WebSocket, skipping recording/scene commands" -ForegroundColor Yellow
            } else {
                if (-not $NoStopRecording) {
                    Write-Step "Stopping OBS recording..."
                    $result = Invoke-ObsRequest -WebSocket $ws -RequestType "StopRecord"
                    if ($result) { Write-Ok "Recording stopped" }
                    else { Write-Host "  [!] StopRecord returned no result (may already be stopped)" -ForegroundColor Yellow }
                }

                if (-not $NoSceneSwitch) {
                    Write-Step "Switching to End of Stream scene..."
                    $sceneData = "{`"sceneName`":`"$($Scene_EndOfStream)`"}"
                    $result = Invoke-ObsRequest -WebSocket $ws -RequestType "SetCurrentProgramScene" -RequestData $sceneData
                    if ($result) { Write-Ok "Scene switched to '$Scene_EndOfStream'" }
                    else { Write-Host "  [!] Scene switch failed (scene may not exist)" -ForegroundColor Yellow }
                }

                Disconnect-ObsWebSocket $ws
                Write-Ok "OBS WebSocket disconnected"
            }
        } catch {
            Write-Host "  [!] OBS WebSocket error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [!] OBS WebSocket module not found, skipping OBS commands" -ForegroundColor Yellow
    }
}

if (-not $KeepData) {
    Write-Step "Cleaning up transient overlay data..."
    $filesToRemove = @(
        (Join-Path $Overlays_Dir "chat-data.json"),
        (Join-Path $Overlays_Dir "alerts-queue.json"),
        (Join-Path $Overlays_Dir "np-data.js"),
        (Join-Path $Overlays_Dir "audio-levels.js")
    )
    $removed = 0
    foreach ($f in $filesToRemove) {
        if (Test-Path $f) {
            Remove-Item $f -Force -ErrorAction SilentlyContinue
            $removed++
        }
    }
    Write-Ok "Removed $removed transient file(s)"
}

Write-Step "Stream summary..."
$chatDataFile = Join-Path $Overlays_Dir "chat-data.json"
$alertsFile = Join-Path $Overlays_Dir "alerts-queue.json"

$chatCount = 0
$alertBreakdown = @{}
$alertTotal = 0
$streamDuration = "unknown"

if (Test-Path $chatDataFile) {
    try {
        $chatData = Get-Content $chatDataFile -Raw | ConvertFrom-Json
        $chatCount = @($chatData.messages).Count
    } catch {}
}

if (Test-Path $alertsFile) {
    try {
        $alertData = Get-Content $alertsFile -Raw | ConvertFrom-Json
        $alertTotal = @($alertData.alerts).Count
        foreach ($a in $alertData.alerts) {
            $key = $a.type
            if (-not $alertBreakdown.ContainsKey($key)) { $alertBreakdown[$key] = 0 }
            $alertBreakdown[$key]++
        }
    } catch {}
}

$monitorLogs = Get-ChildItem "$Logs_Dir\stream-monitor-*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
if ($monitorLogs.Count -gt 0) {
    $firstLog = $monitorLogs[-1]
    $lastLog = $monitorLogs[0]
    if ($firstLog.LastWriteTime -and $lastLog.LastWriteTime) {
        $duration = $lastLog.LastWriteTime - $firstLog.LastWriteTime
        $streamDuration = "$($duration.Hours)h $($duration.Minutes)m $($duration.Seconds)s"
    }
}

Write-Host ""
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host "       STREAM SUMMARY                    " -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""
Write-Info "Duration"        "$streamDuration"
Write-Info "Chat messages"   "$chatCount"
Write-Info "Alerts received" "$alertTotal"
if ($alertBreakdown.Count -gt 0) {
    $alertBreakdown.Keys | ForEach-Object {
        Write-Info "  · $($_): " "$($alertBreakdown[$_])"
    }
}
Write-Info "Jobs stopped"    "$stopped"
Write-Info "Recording"       "$(if (-not $NoStopRecording) { 'Stopped' } else { 'Left running' })"
Write-Info "Scene"            "$(if (-not $NoSceneSwitch) { "Switched to '$Scene_EndOfStream'" } else { 'Left as-is' })"
Write-Info "Cleanup"         "$(if ($KeepData) { 'Kept' } else { 'Removed' })"
Write-Host ""
Write-Ok "All done. Good stream!"
