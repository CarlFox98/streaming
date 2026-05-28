<#
.SYNOPSIS
    Polls OBS audio levels and writes to audio-levels.js for overlay consumption.
#>

. "$env:USERPROFILE\Streaming\config.ps1"

$outputFile = "$Overlays_Dir\audio-levels.js"
$audioSource = "Spotify"
$maxRetries = 5
$retryDelay = 2

Add-Type -AssemblyName System.Net.WebSockets -ErrorAction SilentlyContinue

function Send-Message($ws, $msg) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($msg)
    $seg = New-Object System.ArraySegment[byte] -ArgumentList @(,$bytes)
    $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [System.Threading.CancellationToken]::None).Wait()
}

function Receive-Message($ws) {
    $sb = New-Object System.Text.StringBuilder
    $buf = New-Object byte[] 65536
    do {
        $r = $ws.ReceiveAsync((New-Object System.ArraySegment[byte] -ArgumentList @(,$buf)), [System.Threading.CancellationToken]::None).Result
        if ($r.MessageType -eq [System.Net.WebSockets.WebSocketMessageType]::Close) { return $null }
        $sb.Append([System.Text.Encoding]::UTF8.GetString($buf, 0, $r.Count)) | Out-Null
    } while (-not $r.EndOfMessage)
    return $sb.ToString()
}

function Connect-Obs($obsHost, $port, $password) {
    $ws = New-Object System.Net.WebSockets.ClientWebSocket
    $ws.ConnectAsync([System.Uri]"ws://${obsHost}:${port}", [System.Threading.CancellationToken]::None).Wait()
    $raw = Receive-Message($ws)
    $hello = $raw | ConvertFrom-Json

    $sha = [System.Security.Cryptography.SHA256]::Create()
    $combined = $password + $hello.d.authentication.salt
    $secretHash = [Convert]::ToBase64String($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combined)))
    $combined2 = $secretHash + $hello.d.authentication.challenge
    $authResponse = [Convert]::ToBase64String($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($combined2)))

    $identify = "{`"op`":1,`"d`":{`"rpcVersion`":1,`"authentication`":`"$authResponse`"}}"
    Send-Message $ws $identify
    Receive-Message($ws) | Out-Null
    return $ws
}

function Invoke-Obs($ws, $type, $data) {
    $id = [guid]::NewGuid().ToString()
    $msg = "{`"op`":6,`"d`":{`"requestType`":`"$type`",`"requestId`":`"$id`",`"requestData`":$data}}"
    Send-Message $ws $msg
    return Receive-Message($ws) | ConvertFrom-Json
}

$retries = 0
while ($retries -lt $maxRetries) {
    try {
        Write-Output "Connecting to OBS WebSocket..."
        $ws = Connect-Obs $OBS_Host $OBS_Port $OBS_Password
        Write-Output "Connected. Polling audio levels every 150ms..."

        $lastLevel = -1

        while ($true) {
            try {
                $resp = Invoke-Obs $ws "GetInputVolume" "{`"inputName`":`"$audioSource`"}"
                $level = [Math]::Round($resp.d.responseData.inputVolumeMul, 4)
            } catch {
                $level = -1
            }

            if ($level -ne $lastLevel) {
                $levelStr = if ($level -ge 0) { $level.ToString('0.####') } else { "0" }
                Set-Content -Path $outputFile -Value "window._al={l:$levelStr};" -NoNewline
                $lastLevel = $level
            }

            Start-Sleep -Milliseconds $intervalMs
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
