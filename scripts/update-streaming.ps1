<#
.SYNOPSIS
    Checks GitHub for newer commits to the streaming repo,
    pulls changes, and recompiles EXEs if needed.

    Called automatically by go-live.ps1 on startup.
    Can also be run standalone.
#>

param(
    [string]$BuildInfoPath = "$env:USERPROFILE\Streaming\build-info.json",
    [switch]$Force
)

$repoDir = "$env:USERPROFILE\Streaming"
$repoBranch = "master"

$exes = @(
    @{Name="go-live.exe";     Source="go-live.ps1"},
    @{Name="end-stream.exe";  Source="end-stream.ps1"},
    @{Name="Stream Mode.exe"; Source="scripts\start-stream-mode.ps1"}
)

$logDir = Join-Path $repoDir "logs"
$updaterLog = Join-Path $logDir "update-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"

function Write-UpdateLog {
    param($Msg)
    $ts = Get-Date -Format "HH:mm:ss"
    try {
        "$ts [UPDATE] $Msg" | Out-File $updaterLog -Encoding utf8 -Append
    } catch {}
    Write-Host "  [:)] $Msg" -ForegroundColor DarkGray
}

function Get-LocalCommit {
    if (Test-Path $BuildInfoPath) {
        try {
            $info = Get-Content $BuildInfoPath -Raw | ConvertFrom-Json
            return $info.commit
        } catch { return $null }
    }
    return $null
}

function Update-BuildInfo {
    param($CommitSha)
    $info = @{
        version = "0.2.2"
        commit = $CommitSha
        updatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    }
    $info | ConvertTo-Json -Compress | Set-Content $BuildInfoPath -Encoding utf8 -NoNewline
    Write-UpdateLog "build-info.json updated to commit $($CommitSha.Substring(0, 7))"
}

function Invoke-Recompile {
    Write-UpdateLog "Recompiling EXEs..."
    Import-Module ps2exe -Force -ErrorAction SilentlyContinue
    if (-not (Get-Command Invoke-ps2exe -ErrorAction SilentlyContinue)) {
        Write-UpdateLog "PS2EXE module not found, skipping recompile"
        return $false
    }
    $allOk = $true
    foreach ($exe in $exes) {
        $srcPath = Join-Path $repoDir $exe.Source
        $exePath = Join-Path $repoDir $exe.Name
        if (-not (Test-Path $srcPath)) {
            Write-UpdateLog "Source not found: $($exe.Source), skipping"
            $allOk = $false
            continue
        }
        $title = [System.IO.Path]::GetFileNameWithoutExtension($exe.Name)
        try {
            $null = Invoke-ps2exe -inputFile $srcPath -outputFile $exePath -title $title -version "0.2.2.0" -noOutput -noError
            Write-UpdateLog "  Recompiled: $($exe.Name)"
        } catch {
            Write-UpdateLog "  FAILED: $($exe.Name) - $($_.Exception.Message)"
            $allOk = $false
        }
    }
    return $allOk
}

$localCommit = Get-LocalCommit
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

try {
    Write-UpdateLog "Fetching latest from GitHub..."
    $prevDir = Get-Location
    try {
        Set-Location -LiteralPath $repoDir
        git fetch origin $repoBranch 2>&1 | Out-Null
    } finally {
        Set-Location -LiteralPath $prevDir
    }

    if ($LASTEXITCODE -ne 0) {
        Write-UpdateLog "git fetch failed - check network or remote URL"
        exit 1
    }

    $prevDir = Get-Location
    try {
        Set-Location -LiteralPath $repoDir
        $remoteSha = git rev-parse "origin/$repoBranch" 2>$null
        $needsUpdate = $Force -or (-not $localCommit) -or ($localCommit -ne $remoteSha)
    } finally {
        Set-Location -LiteralPath $prevDir
    }

    if (-not $remoteSha) {
        Write-UpdateLog "Could not determine remote commit SHA (no remote tracking branch?)"
        exit 1
    }

    $localShort = if ($localCommit) { $localCommit.Substring(0, 7) } else { "none" }
    Write-UpdateLog "Local: ${localShort}  Remote: $($remoteSha.Substring(0, 7))"

    if (-not $needsUpdate) {
        Write-UpdateLog "Already up to date."
        exit 0
    }

    $prevDir = Get-Location
    try {
        Set-Location -LiteralPath $repoDir
        Write-UpdateLog "Pulling changes..."
        $pullOut = git pull origin $repoBranch 2>&1
        foreach ($line in $pullOut) { Write-UpdateLog "  git: $line" }
        if ($LASTEXITCODE -ne 0 -or -not $pullOut) {
            Write-UpdateLog "git pull failed - local changes may conflict"
            exit 1
        }
    } finally {
        Set-Location -LiteralPath $prevDir
    }

    $recompiled = Invoke-Recompile
    if ($recompiled) {
        Update-BuildInfo $remoteSha
        Write-UpdateLog "Update complete."
    } else {
        Write-UpdateLog "Update partial - some EXEs may need manual recompile."
    }
    exit 0
} catch {
    Write-UpdateLog "Update failed: $($_.Exception.Message)"
    exit 1
}
