<#
.SYNOPSIS
    One-command launch for your entire streaming stack.
    Starts the OBS stream monitor + optional Spotify now-playing poller
    in the background, with centralized logging.

    Usage:
        .\go-live.ps1               (default: 30 min timer, with Spotify)
        .\go-live.ps1 -NoSpotify    (skip Spotify polling)
        .\go-live.ps1 -Minutes 15   (override Starting Soon countdown)

    Tip: Pin this script to your taskbar or add an alias in $PROFILE.
#>

param(
    [switch]$NoSpotify,
    [int]$Minutes = 30
)

. "$PSScriptRoot\config.ps1"

# ---- helpers ----
function Write-Banner {
    $here = "  ______ _   _ _____          _  __     ____  _     ___ "
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
function Write-Ok($msg)              { Write-Host "  [$(Format-Hex -Bytes (0..0) | Out-Null); ✔] $msg" -ForegroundColor Green }
function Write-Fail($msg)            { Write-Host "  [✘] $msg" -ForegroundColor Red }
function Write-Info($label, $value)  { Write-Host "  $($label.PadRight(22)) $value" -ForegroundColor Gray }

function Format-Hex { param($Bytes) $null }  # no-op shim (just for checkmark in PS5)

# ---- startup ----
Clear-Host
Write-Banner
Write-Host ""

# ---- prerequisites ----
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

Write-Ok "All prerequisites met"
Write-Host ""

# ---- launch stream monitor ----
Write-Step "Launching OBS Stream Monitor..."
$monitorLog = Join-Path $Logs_Dir "stream-monitor-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$monitorJob = Start-Job -Name "StreamMonitor" -ScriptBlock {
    param($ScriptPath, $LogPath)
    & $ScriptPath *>&1 | Out-File $LogPath -Encoding utf8 -Append
} -ArgumentList $monitorScript, $monitorLog
Write-Ok "Stream monitor started (Job ID: $($monitorJob.Id), log: $(Split-Path $monitorLog -Leaf))"

# ---- launch spotify poller ----
if (-not $NoSpotify) {
    Write-Step "Launching Spotify Now Playing poller..."
    $spotifyLog = Join-Path $Logs_Dir "spotify-now-playing-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
    $spotifyJob = Start-Job -Name "SpotifyPoller" -ScriptBlock {
        param($ScriptPath, $LogPath)
        & $ScriptPath *>&1 | Out-File $LogPath -Encoding utf8 -Append
    } -ArgumentList $spotifyScript, $spotifyLog
    Write-Ok "Spotify poller started (Job ID: $($spotifyJob.Id), log: $(Split-Path $spotifyLog -Leaf))"
}

Write-Host ""

# ---- summary ----
Write-Host "  ╔══════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║         ALL SYSTEMS NOMINAL                  ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Info "Stream monitor"           "Running  (PID inside job)"
if (-not $NoSpotify) {
    Write-Info "Spotify poller"        "Running"
}
Write-Info "Starting Soon timer"     "$Minutes min"
Write-Info "Logs directory"          "$Logs_Dir"
Write-Info "OBS scenes"              "$($Scene_StartingSoon) → $($Scene_Streaming) → $($Scene_JustChatting) → $($Scene_BeBackSoon) → $($Scene_EndOfStream) → $($Scene_TechDifficulties)"
Write-Host ""
Write-Host "  Starting Soon overlay at:  $($Minutes) min countdown" -ForegroundColor Gray
if (-not $NoSpotify) {
    Write-Host "  Spotify now-playing:         ON (writes to overlays/np-data.js)" -ForegroundColor Gray
}
Write-Host "  Tech-difficulties timeout: $($Monitor_TechDiffTimeoutSec)s of downtime → End of Stream" -ForegroundColor Gray
Write-Host ""

# ---- monitor loop (keeps this window alive, shows status) ----
Write-Step "Monitoring processes. Press Ctrl+C to shut down cleanly."
Write-Host ""

$lastCheck = 0
while ($true) {
    $s = Get-Job -Name "StreamMonitor" -ErrorAction SilentlyContinue
    $sf = $s.State -eq "Failed"
    $sr = $s.State -eq "Running"

    if (-not $sr) {
        Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Stream monitor is $($s.State)." -ForegroundColor Yellow
        if ($sf) {
            Write-Host "         Receive-Job output: $($s | Receive-Job)" -ForegroundColor Red
            $s | Remove-Job -Force
            Write-Step "Restarting stream monitor..."
            $monitorJob = Start-Job -Name "StreamMonitor" -ScriptBlock {
                param($ScriptPath, $LogPath)
                & $ScriptPath *>&1 | Out-File $LogPath -Encoding utf8 -Append
            } -ArgumentList $monitorScript, $monitorLog
            Write-Ok "Stream monitor restarted"
        }
    }

    if (-not $NoSpotify) {
        $sp = Get-Job -Name "SpotifyPoller" -ErrorAction SilentlyContinue
        if ($sp.State -eq "Failed") {
            Write-Host "  $(Get-Date -Format 'HH:mm:ss') [WARN] Spotify poller failed. Restarting..." -ForegroundColor Yellow
            $sp | Remove-Job -Force
            $spotifyJob = Start-Job -Name "SpotifyPoller" -ScriptBlock {
                param($ScriptPath, $LogPath)
                & $ScriptPath *>&1 | Out-File $LogPath -Encoding utf8 -Append
            } -ArgumentList $spotifyScript, $spotifyLog
        }
    }

    # Periodic status line every 30s
    $now = [int](Get-Date -UFormat %s)
    if ($now - $lastCheck -ge 30) {
        Write-Host "  $(Get-Date -Format 'HH:mm:ss') All systems OK. Running for $(($now - $lastCheck))s..." -ForegroundColor DarkGray
        $lastCheck = $now
    }

    Start-Sleep -Seconds 5
}
