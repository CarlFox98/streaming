<#
.SYNOPSIS
    Polls OBS audio levels and writes to audio-levels.js for overlay consumption.
#>

. "$env:USERPROFILE\Streaming\config.ps1"
Import-Module "$env:USERPROFILE\.config\opencode\modules\obs\scripts\obs-wsapi.psm1" -Force

$outputFile = "$Overlays_Dir\audio-levels.js"
$audioSource = "Spotify"
$maxRetries = 5
$retryDelay = 2

$retries = 0
while ($retries -lt $maxRetries) {
    try {
        Write-Output "Connecting to OBS WebSocket..."
        $ws = Connect-ObsWebSocket -Host $OBS_Host -Port $OBS_Port -Password $OBS_Password
        Write-Output "Connected. Polling audio levels every ${Monitor_AudioVisIntervalMs}ms..."

        $lastLevel = -1

        while ($true) {
            try {
                $resp = Invoke-ObsRequest -WebSocket $ws -RequestType "GetInputVolume" -RequestData "{`"inputName`":`"$audioSource`"}"
                $level = [Math]::Round($resp.inputVolumeMul, 4)
            } catch {
                $level = -1
            }

            if ($level -ne $lastLevel) {
                $levelStr = if ($level -ge 0) { $level.ToString('0.####') } else { "0" }
                Set-Content -Path $outputFile -Value "window._al={l:$levelStr};" -NoNewline
                $lastLevel = $level
            }

            Start-Sleep -Milliseconds $Monitor_AudioVisIntervalMs
        }
    } catch {
        $retries++
        Write-Output "Error: $($_.Exception.Message)"
        if ($retries -lt $maxRetries) {
            Write-Output "Retrying in ${retryDelay}s (attempt $retries/$maxRetries)..."
            Start-Sleep -Seconds $retryDelay
        } else {
            Write-Output "Max retries reached. Exiting."
        }
    }
}
