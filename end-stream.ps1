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

# ---- helpers ----
function Write-Step($msg)   { Write-Host "  >> $msg" -ForegroundColor Yellow }
function Write-Ok($msg)     { Write-Host "  [+]$msg" -ForegroundColor Green }
function Write-Info($l,$v)  { Write-Host "  $($l.PadRight(22)) $v" -ForegroundColor Gray }

Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host "       END STREAM                        " -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""

# ---- 1. Stop background jobs ----
Write-Step "Stopping background daemons..."
$jobNames = @("StreamMonitor", "SpotifyPoller", "AudioVis", "TwitchChat")
$stopped = 0
foreach ($name in $jobNames) {
    $job = Get-Job -Name $name -ErrorAction SilentlyContinue
    if ($job) {
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        Write-Info "Stopped" "$name"
        $stopped++
    }
}
Write-Ok "Stopped $stopped background job(s)"

# ---- 2. OBS stop recording + scene switch ----
if (-not $NoStopRecording -or -not $NoSceneSwitch) {
    Write-Step "Connecting to OBS WebSocket..."
    $wsModule = "$env:USERPROFILE\.config\opencode\modules\obs\scripts\obs-wsapi.psm1"
    if (Test-Path $wsModule) {
        Import-Module $wsModule -Force -ErrorAction SilentlyContinue
        try {
            $ws = $null
            $ws = Connect-ObsWebSocket -Host $OBS_Host -Port $OBS_Port -Password $OBS_Password

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
        } catch {
            Write-Host "  [!] OBS WebSocket error: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "  [!] OBS WebSocket module not found, skipping OBS commands" -ForegroundColor Yellow
    }
}

# ---- 3. Clean up transient data ----
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

# ---- 4. Session summary ----
Write-Host ""
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host "       STREAM ENDED                      " -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""
Write-Info "Jobs stopped"   "$stopped"
Write-Info "Recording"      "$(if (-not $NoStopRecording) { 'Stopped' } else { 'Left running' })"
Write-Info "Scene"           "$(if (-not $NoSceneSwitch) { "Switched to '$Scene_EndOfStream'" } else { 'Left as-is' })"
Write-Info "Cleanup"        "$(if ($KeepData) { 'Kept' } else { 'Removed' })"
Write-Host ""
Write-Ok "All done. Good stream!"
