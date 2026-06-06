<#
.SYNOPSIS
    One-command launch for your entire streaming stack.

    Usage:
        .\go-live.ps1               (default: 30 min timer, with Spotify)
        .\go-live.ps1 -NoSpotify    (skip Spotify polling)
        .\go-live.ps1 -Minutes 15   (override Starting Soon countdown)

    Tip: Pin this script to your taskbar or add an alias in $PROFILE.
#>

param(
    [switch]$NoSpotify,
    [switch]$NoAudioVis,
    [switch]$NoChat,
    [switch]$NoHotkeys,
    [switch]$Force,
    [ValidateRange(1, 999)]
    [int]$Minutes = 30
)

$global:consoleHost = $host
$consoleHost.UI.RawUI.WindowTitle = "Go Live"

$configPath = "$env:USERPROFILE\Streaming\config.ps1"
if (-not (Test-Path $configPath)) {
    Write-Host "[!] Config not found: $configPath" -ForegroundColor Red
    Write-Host "[!] Copy config.ps1.example to config.ps1 and fill in your settings." -ForegroundColor Red
    exit 1
}
. $configPath

$scriptRoot = "$env:USERPROFILE\Streaming"

function Write-Banner {
    $here =  "  ______ _   _ _____          _  __     ____  _     ___ "
    $here2 = " |  ____| \ | |  __ \   /\   | | \ \   / __ \| |   |__ \"
    $here3 = " | |__  |  \| | |  | | /  \  | |  \ \ | |  | | |      ) |"
    $here4 = " |  __| | . ` | |  | |/ /\ \ | |   \ \| |  | | |     / /"
    $here5 = " | |____| |\  | |__| / ____ \| |____\ \ |__| | |____/ /_"
    $here6 = " |______|_| \_|_____/_/    \_\______| \_\___\_\_____|____|"
    Write-Host " " -NoNewline
    Write-Host $here -ForegroundColor Cyan
    Write-Host $here2 -ForegroundColor Cyan
    Write-Host $here3 -ForegroundColor Cyan
    Write-Host $here4 -ForegroundColor Cyan
    Write-Host $here5 -ForegroundColor Cyan
    Write-Host $here6 -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($msg)            { Write-Host "  >> $msg" -ForegroundColor Yellow }
function Write-Ok($msg)              { Write-Host "  [+] $msg" -ForegroundColor Green }
function Write-Fail($msg)            { Write-Host "  [!] $msg" -ForegroundColor Red }
function Write-Info($label, $value)  { Write-Host "  $($label.PadRight(22)) $value" -ForegroundColor Gray }

Clear-Host
Write-Banner
Write-Host ""

Write-Step "Checking prerequisites..."

$obsProcess = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
if (-not $obsProcess) {
    Write-Fail "OBS is not running. Please start OBS first."
    exit 1
}
Write-Ok "OBS running (PID: $($obsProcess.Id))"

if (-not (Test-Path $Logs_Dir)) {
    New-Item -ItemType Directory -Path $Logs_Dir -Force | Out-Null
    Write-Ok "Created logs directory: $Logs_Dir"
}

$monitorScript = "$env:USERPROFILE\.config\opencode\modules\obs\scripts\obs-stream-monitor.ps1"
if (-not (Test-Path $monitorScript)) {
    Write-Fail "Stream monitor script not found: $monitorScript"
    exit 1
}

$spotifyScript = "$env:USERPROFILE\.config\opencode\modules\obs\scripts\spotify-now-playing.ps1"
if (-not $NoSpotify -and -not (Test-Path $spotifyScript)) {
    Write-Warning "Spotify poller script not found, skipping: $spotifyScript"
    $NoSpotify = $true
}

$audioVisScript = "$env:USERPROFILE\Streaming\scripts\obs-audio-vis.ps1"
if (-not $NoAudioVis -and -not (Test-Path $audioVisScript)) {
    Write-Warning "Audio visualizer script not found, skipping: $audioVisScript"
    $NoAudioVis = $true
}

$chatDaemonScript = "$env:USERPROFILE\.config\opencode\modules\obs\twitch\twitch-chat-daemon.ps1"
if (-not $NoChat -and -not (Test-Path $chatDaemonScript)) {
    Write-Warning "Chat daemon script not found, skipping: $chatDaemonScript"
    $NoChat = $true
}

$hotkeyScript = "$env:USERPROFILE\.config\opencode\modules\obs\scripts\obs-hotkeys.ps1"
if (-not $NoHotkeys -and -not (Test-Path $hotkeyScript)) {
    Write-Warning "Hotkey daemon script not found, skipping: $hotkeyScript"
    $NoHotkeys = $true
}

Write-Step "Rotating old logs..."
try {
    $logFiles = Get-ChildItem "$Logs_Dir\*.log" | Sort-Object LastWriteTime -Descending
    $toRemove = $logFiles | Select-Object -Skip $LogRetentionMaxFiles
    foreach ($f in $toRemove) {
        Remove-Item $f.FullName -Force
        Write-Info "Removed old log" "$($f.Name)"
    }
    Write-Ok "Log rotation done ($(@($logFiles).Count) files, keeping $LogRetentionMaxFiles)"
} catch {
    Write-Info "Log rotation" "Skipped ($($_.Exception.Message))"
}

Write-Step "Checking for existing daemon jobs..."
$existingJobs = @()
$jobNames = @("StreamMonitor", "SpotifyPoller", "AudioVis", "TwitchChat", "HotkeyDaemon")
foreach ($n in $jobNames) {
    $j = Get-Job -Name $n -ErrorAction SilentlyContinue
    if ($j) { $existingJobs += $n }
}
if ($existingJobs.Count -gt 0) {
    Write-Host "  [!] Existing jobs found: $($existingJobs -join ', ')" -ForegroundColor Yellow
    if (-not $Force) {
        Write-Host "  [!] Run with -Force to proceed anyway, or run end-stream.ps1 first." -ForegroundColor Yellow
        exit 1
    }
    Write-Host "  [+] -Force set, stopping existing jobs..." -ForegroundColor DarkGray
    foreach ($n in $existingJobs) {
        $j = Get-Job -Name $n -ErrorAction SilentlyContinue
        if ($j) {
            $null = $j | Stop-Job -Force -ErrorAction SilentlyContinue
            $null = $j | Receive-Job -ErrorAction SilentlyContinue
            $j | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }
    Write-Ok "Stopped $($existingJobs.Count) existing job(s)"
}
Write-Ok "No duplicate run detected"

if (-not $NoChat) {
    Write-Step "Validating Twitch credentials..."
    $twitchModule = "$env:USERPROFILE\.config\opencode\modules\obs\twitch\twitch-module.ps1"
    $twitchToken = "$env:USERPROFILE\.config\opencode\modules\obs\twitch\twitch-token.enc"
    if (Test-Path $twitchToken) {
        try {
            . $twitchModule
            $null = Get-TwitchStreamStatus -ErrorAction SilentlyContinue
            Write-Ok "Twitch credentials valid"
        } catch {
            Write-Host "  [!] Twitch validation failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  [!] Chat daemon may not connect. Run twitch-module.ps1 -Setup to re-authenticate." -ForegroundColor Yellow
        }
    } else {
        Write-Host "  [!] No Twitch token found. Chat daemon will not connect." -ForegroundColor Yellow
        Write-Host "  [!] Run: twitch-module.ps1 -Setup" -ForegroundColor Yellow
    }
}

Write-Ok "All prerequisites met"
Write-Host ""

function Restart-JobWithLog {
    param($Name, $ScriptPath, $LogPath, $Arguments, $ScriptBlock)
    $job = Start-Job -Name $Name -ScriptBlock $ScriptBlock -ArgumentList $Arguments
    "=== RESTART $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===" | Out-File $LogPath -Encoding utf8 -Append
    Write-Ok "$Name restarted (Job ID: $($job.Id))"
    return $job
}

# helper for monitor daemon script block
$monitorBlock = {
    param($ScriptPath, $LogPath, $HostVal, $Port, $Pass, $PollMs, $TimeoutSec)
    & $ScriptPath -ObsHost $HostVal -ObsPort $Port -ObsPassword $Pass -PollIntervalMs $PollMs -TechDifficultiesTimeoutSec $TimeoutSec *>&1 | Out-File $LogPath -Encoding utf8 -Append
}
$spotifyBlock = {
    param($ScriptPath, $LogPath, $Interval, $OutDir)
    & $ScriptPath -IntervalSeconds $Interval -OutputDir $OutDir *>&1 | Out-File $LogPath -Encoding utf8 -Append
}
$audioVisBlock = {
    param($ScriptPath, $LogPath)
    & $ScriptPath *>&1 | Out-File $LogPath -Encoding utf8 -Append
}
$chatBlock = {
    param($ScriptPath, $LogPath)
    & $ScriptPath *>&1 | Out-File $LogPath -Encoding utf8 -Append
}
$hotkeyBlock = {
    param($ScriptPath, $LogPath, $PollMs, $AfdMin, $AfdPollMs)
    & $ScriptPath -PollIntervalMs $PollMs -AfdTimeoutMinutes $AfdMin -AfdPollIntervalMs $AfdPollMs *>&1 | Out-File $LogPath -Encoding utf8 -Append
}

$monitorLog = Join-Path $Logs_Dir "stream-monitor-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Write-Step "Launching OBS Stream Monitor..."
$monitorJob = Start-Job -Name "StreamMonitor" -ScriptBlock $monitorBlock -ArgumentList $monitorScript, $monitorLog, $OBS_Host, $OBS_Port, $OBS_Password, $Monitor_PollIntervalMs, $Monitor_TechDiffTimeoutSec
Write-Ok "Stream monitor started (Job ID: $($monitorJob.Id), log: $(Split-Path $monitorLog -Leaf))"

if (-not $NoSpotify) {
    Write-Step "Launching Spotify Now Playing poller..."
    $spotifyLog = Join-Path $Logs_Dir "spotify-now-playing-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $spotifyJob = Start-Job -Name "SpotifyPoller" -ScriptBlock $spotifyBlock -ArgumentList $spotifyScript, $spotifyLog, $Spotify_PollIntervalSec, $Overlays_Dir
    Write-Ok "Spotify poller started (Job ID: $($spotifyJob.Id), log: $(Split-Path $spotifyLog -Leaf))"
}

if (-not $NoAudioVis) {
    Write-Step "Launching Audio Visualizer daemon..."
    $audioVisLog = Join-Path $Logs_Dir "audio-vis-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $audioVisJob = Start-Job -Name "AudioVis" -ScriptBlock $audioVisBlock -ArgumentList $audioVisScript, $audioVisLog
    Write-Ok "Audio visualizer started (Job ID: $($audioVisJob.Id), log: $(Split-Path $audioVisLog -Leaf))"
}

if (-not $NoChat) {
    Write-Step "Launching Twitch Chat daemon..."
    $chatLog = Join-Path $Logs_Dir "twitch-chat-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $chatJob = Start-Job -Name "TwitchChat" -ScriptBlock $chatBlock -ArgumentList $chatDaemonScript, $chatLog
    Write-Ok "Twitch Chat daemon started (Job ID: $($chatJob.Id), log: $(Split-Path $chatLog -Leaf))"
}

if (-not $NoHotkeys) {
    Write-Step "Launching Hotkey daemon..."
    $hotkeyLog = Join-Path $Logs_Dir "hotkeys-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $hotkeyJob = Start-Job -Name "HotkeyDaemon" -ScriptBlock $hotkeyBlock -ArgumentList $hotkeyScript, $hotkeyLog, $Hotkey_PollIntervalMs, $AFK_TimeoutMinutes, $AFK_PollIntervalMs
    Write-Ok "Hotkey daemon started (Job ID: $($hotkeyJob.Id), log: $(Split-Path $hotkeyLog -Leaf))"
}

if ($Timer_SceneSwitchAuto) {
    Write-Step "Scheduling auto scene switch: '$Scene_Streaming' in ${Minutes} minutes..."
    $timerLog = Join-Path $Logs_Dir "timer-scene-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $timerJob = Start-Job -Name "TimerSceneSwitch" -ScriptBlock {
        param($Minutes2, $SceneStreaming, $ObsHost, $ObsPort, $ObsPass, $WsModule, $LogPath)
        Start-Sleep -Seconds ($Minutes2 * 60)
        try {
            Import-Module $WsModule -Force
            $ws = Connect-ObsWebSocket -Host $ObsHost -Port $ObsPort -Password $ObsPass
            $data = "{`"sceneName`":`"$SceneStreaming`"}"
            $null = Invoke-ObsRequest -WebSocket $ws -RequestType "SetCurrentProgramScene" -RequestData $data
            Disconnect-ObsWebSocket $ws
            "Auto scene switch: $SceneStreaming at $(Get-Date)" | Out-File $LogPath -Encoding utf8 -Append
        } catch {
            "Timer scene switch failed: $_" | Out-File $LogPath -Encoding utf8 -Append
        }
        Remove-Job -Name "TimerSceneSwitch" -Force -ErrorAction SilentlyContinue
    } -ArgumentList $Minutes, $Scene_Streaming, $OBS_Host, $OBS_Port, $OBS_Password, "$env:USERPROFILE\.config\opencode\modules\obs\scripts\obs-wsapi.psm1", $timerLog
    Write-Ok "Auto scene switch scheduled (job: $($timerJob.Id), switch to '$Scene_Streaming' in ${Minutes}m)"
}

Write-Host ""

Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host "       ALL SYSTEMS NOMINAL               " -ForegroundColor Cyan
Write-Host "  ======================================" -ForegroundColor Cyan
Write-Host ""
Write-Info "Stream monitor"           "Running  (PID inside job)"
if (-not $NoSpotify) { Write-Info "Spotify poller"        "Running" }
if (-not $NoAudioVis) { Write-Info "Audio visualizer"      "Running" }
if (-not $NoChat) { Write-Info "Twitch Chat"           "Running" }
if (-not $NoHotkeys) { Write-Info "Hotkey daemon"         "Running" }
if ($Timer_SceneSwitchAuto) { Write-Info "Auto scene switch"     "'$Scene_Streaming' in ${Minutes}m" }
Write-Info "Starting Soon timer"     "$Minutes min"
Write-Info "Logs directory"          "$Logs_Dir"
Write-Info "OBS scenes"              "$($Scene_StartingSoon) > $($Scene_Streaming) > $($Scene_JustChatting) > $($Scene_BeBackSoon) > $($Scene_EndOfStream) > $($Scene_TechDifficulties)"
Write-Host ""

Write-Step "Monitoring processes. Press Ctrl+C to shut down cleanly."
Write-Host ""

$script:cleanupDone = $false
$script:keepMonitoring = $true

$cleanupHandler = {
    if ($script:cleanupDone) { return }
    $script:cleanupDone = $true
    $script:keepMonitoring = $false
    Write-Host "`n  [!] Ctrl+C detected. Stopping daemon jobs..." -ForegroundColor Yellow
    $jobs = Get-Job -ErrorAction SilentlyContinue
    foreach ($j in $jobs) {
        $null = $j | Stop-Job -Force -ErrorAction SilentlyContinue
        $null = $j | Receive-Job -ErrorAction SilentlyContinue
        $j | Remove-Job -Force -ErrorAction SilentlyContinue
    }
    Write-Host "  [+] All jobs stopped." -ForegroundColor Green
}
[Console]::CancelKeyPress.Add_CancelKeyPress($cleanupHandler)

$startTime = Get-Date
$lastCheck = Get-Date

while ($script:keepMonitoring) {
    try {
        $s = Get-Job -Name "StreamMonitor" -ErrorAction SilentlyContinue
        if ($s -and $s.State -eq "Failed") {
            Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Stream monitor failed." -ForegroundColor Yellow
            $null = $s | Receive-Job -ErrorAction SilentlyContinue
            $s | Remove-Job -Force
            $monitorJob = Restart-JobWithLog -Name "StreamMonitor" -ScriptPath $monitorScript -LogPath $monitorLog -ScriptBlock $monitorBlock -Arguments @($monitorScript, $monitorLog, $OBS_Host, $OBS_Port, $OBS_Password, $Monitor_PollIntervalMs, $Monitor_TechDiffTimeoutSec)
        } elseif (-not $s) {
            Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Stream monitor job missing. Restarting..." -ForegroundColor Yellow
            $monitorJob = Restart-JobWithLog -Name "StreamMonitor" -ScriptPath $monitorScript -LogPath $monitorLog -ScriptBlock $monitorBlock -Arguments @($monitorScript, $monitorLog, $OBS_Host, $OBS_Port, $OBS_Password, $Monitor_PollIntervalMs, $Monitor_TechDiffTimeoutSec)
        }
    } catch {
        Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Stream monitor check failed: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    try {
        if (-not $NoSpotify) {
            $sp = Get-Job -Name "SpotifyPoller" -ErrorAction SilentlyContinue
            if ($sp -and $sp.State -eq "Failed") {
                Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Spotify poller failed. Restarting..." -ForegroundColor Yellow
                $null = $sp | Receive-Job -ErrorAction SilentlyContinue
                $sp | Remove-Job -Force
                $spotifyJob = Restart-JobWithLog -Name "SpotifyPoller" -ScriptPath $spotifyScript -LogPath $spotifyLog -ScriptBlock $spotifyBlock -Arguments @($spotifyScript, $spotifyLog, $Spotify_PollIntervalSec, $Overlays_Dir)
            }
        }
    } catch {}

    try {
        if (-not $NoAudioVis) {
            $av = Get-Job -Name "AudioVis" -ErrorAction SilentlyContinue
            if ($av -and $av.State -eq "Failed") {
                Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Audio visualizer failed. Restarting..." -ForegroundColor Yellow
                $null = $av | Receive-Job -ErrorAction SilentlyContinue
                $av | Remove-Job -Force
                $audioVisJob = Restart-JobWithLog -Name "AudioVis" -ScriptPath $audioVisScript -LogPath $audioVisLog -ScriptBlock $audioVisBlock -Arguments @($audioVisScript, $audioVisLog)
            }
        }
    } catch {}

    try {
        if (-not $NoChat) {
            $cj = Get-Job -Name "TwitchChat" -ErrorAction SilentlyContinue
            if ($cj -and $cj.State -eq "Failed") {
                Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Twitch Chat daemon failed. Restarting..." -ForegroundColor Yellow
                $null = $cj | Receive-Job -ErrorAction SilentlyContinue
                $cj | Remove-Job -Force
                $chatJob = Restart-JobWithLog -Name "TwitchChat" -ScriptPath $chatDaemonScript -LogPath $chatLog -ScriptBlock $chatBlock -Arguments @($chatDaemonScript, $chatLog)
            }
        }
    } catch {}

    try {
        if (-not $NoHotkeys) {
            $hj = Get-Job -Name "HotkeyDaemon" -ErrorAction SilentlyContinue
            if ($hj -and $hj.State -eq "Failed") {
                Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Hotkey daemon failed. Restarting..." -ForegroundColor Yellow
                $null = $hj | Receive-Job -ErrorAction SilentlyContinue
                $hj | Remove-Job -Force
                $hotkeyJob = Restart-JobWithLog -Name "HotkeyDaemon" -ScriptPath $hotkeyScript -LogPath $hotkeyLog -ScriptBlock $hotkeyBlock -Arguments @($hotkeyScript, $hotkeyLog, $Hotkey_PollIntervalMs, $AFK_TimeoutMinutes, $AFK_PollIntervalMs)
            }
        }
    } catch {}

    $ts = Get-Job -Name "TimerSceneSwitch" -ErrorAction SilentlyContinue
    if ($ts -and $ts.State -eq "Completed") {
        $null = $ts | Receive-Job -ErrorAction SilentlyContinue
        $ts | Remove-Job -Force
    }

    $elapsed = [math]::Floor(((Get-Date) - $lastCheck).TotalSeconds)
    if ($elapsed -ge 30) {
        $totalRun = [math]::Floor(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "  $(Get-Date -Format 'HH:mm:ss') All systems OK. Running for ${totalRun}s..." -ForegroundColor DarkGray
        $lastCheck = Get-Date
    }

    Start-Sleep -Seconds 5
}

if (-not $script:cleanupDone) {
    $cleanupHandler.Invoke()
}
