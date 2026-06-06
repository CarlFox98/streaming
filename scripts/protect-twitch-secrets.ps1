<#
.SYNOPSIS
    Encrypts Twitch credentials and tokens using Windows DPAPI.
    Run once after OAuth setup to protect secrets at rest.
    Only the same Windows user can decrypt.
#>

$twitchDir = "$env:USERPROFILE\.config\opencode\modules\obs\twitch"

$credFile = Join-Path $twitchDir "twitch-credentials.json"
$tokenFile = Join-Path $twitchDir "twitch-token.json"
$credEnc = Join-Path $twitchDir "twitch-credentials.enc"
$tokenEnc = Join-Path $twitchDir "twitch-token.enc"

function Protect-File($source, $dest) {
    if (-not (Test-Path $source)) {
        Write-Warning "Not found: $source - skipping"
        return $false
    }
    $plain = Get-Content $source -Raw
    $secure = ConvertTo-SecureString -String $plain -AsPlainText -Force
    $encrypted = ConvertFrom-SecureString -SecureString $secure
    $encrypted | Set-Content $dest -NoNewline
    Write-Output "Encrypted: $source -> $dest"
    return $true
}

Write-Output "=== Twitch Secret Protection ==="
$ok1 = Protect-File $credFile $credEnc
$ok2 = Protect-File $tokenFile $tokenEnc

if ($ok1 -and $ok2) {
    Write-Output "`nBoth files encrypted. You may now remove the plaintext originals:"
    Write-Output "  Remove-Item '$credFile'"
    Write-Output "  Remove-Item '$tokenFile'"
    Write-Output "`nThe twitch-module.ps1 will read the .enc files at runtime."
} elseif ($ok1 -or $ok2) {
    Write-Output "`nPartial success - check warnings above."
} else {
    Write-Output "`nNothing to encrypt. Run twitch-module.ps1 -Setup first."
}
