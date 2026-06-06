<#
.SYNOPSIS
    Creates a fresh virtual desktop, launches streaming stack there,
    and cleans up when done.
#>

$host.UI.RawUI.WindowTitle = "Stream Mode"

function Write-Step($m) { Write-Host "  >> $m" -ForegroundColor Yellow }
function Write-Ok($m)   { Write-Host "  [$] $m" -ForegroundColor Green }
function Write-Fail($m) { Write-Host "  [!] $m" -ForegroundColor Red }

Write-Host ""
Write-Host "  ====================================" -ForegroundColor Cyan
Write-Host "     STREAM MODE - Virtual Desktop     " -ForegroundColor Cyan
Write-Host "  ====================================" -ForegroundColor Cyan
Write-Host ""

Add-Type -MemberDefinition @'
[DllImport("user32.dll")]
public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, System.UIntPtr dwExtraInfo);
[DllImport("user32.dll")]
public static extern bool SwitchToThisWindow(System.IntPtr hWnd, bool fAltTab);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool MoveWindow(System.IntPtr hWnd, int x, int y, int nWidth, int nHeight, bool bRepaint);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")]
public static extern bool SetWindowPos(System.IntPtr hWnd, System.IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
[DllImport("user32.dll", SetLastError = true)]
public static extern bool EnumWindows(System.IntPtr lpEnumFunc, System.IntPtr lParam);
[DllImport("user32.dll", SetLastError = true)]
public static extern System.IntPtr GetWindowThreadProcessId(System.IntPtr hWnd, out uint lpdwProcessId);
[DllImport("user32.dll")]
public static extern bool IsWindowVisible(System.IntPtr hWnd);
[DllImport("user32.dll", CharSet = CharSet.Auto)]
public static extern int GetWindowText(System.IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
public delegate bool EnumWindowsProc(System.IntPtr hWnd, System.IntPtr lParam);

public static System.IntPtr FindWindowByPid(uint pid) {
    System.IntPtr found = System.IntPtr.Zero;
    System.IntPtr resultPtr = System.Runtime.InteropServices.Marshal.AllocHGlobal(System.IntPtr.Size);
    System.Runtime.InteropServices.Marshal.WriteIntPtr(resultPtr, System.IntPtr.Zero);
    EnumWindowsProc callback = (hWnd, lParam) => {
        uint p;
        GetWindowThreadProcessId(hWnd, out p);
        if (p == pid && IsWindowVisible(hWnd)) {
            System.Runtime.InteropServices.Marshal.WriteIntPtr(lParam, hWnd);
            return false;
        }
        return true;
    };
    System.IntPtr cb = System.Runtime.InteropServices.Marshal.GetFunctionPointerForDelegate(callback);
    EnumWindows(cb, resultPtr);
    found = System.Runtime.InteropServices.Marshal.ReadIntPtr(resultPtr);
    System.Runtime.InteropServices.Marshal.FreeHGlobal(resultPtr);
    return found;
}

public static readonly System.IntPtr HWND_TOPMOST = new System.IntPtr(-1);
public const int SW_MINIMIZE = 6;
public const int SWP_NOSIZE = 0x0001;
public const int SWP_NOMOVE = 0x0002;
'@ -Name "Input" -Namespace "Win32" -ErrorAction Stop

function Reset-Keys {
    $mods = @(0x11, 0x5B, 0x10, 0x12)
    foreach ($vk in $mods) { [Win32.Input]::keybd_event($vk, 0, 0x02, [UIntPtr]::Zero) }
}

function Send-Combo {
    param([byte]$k1, [byte]$k2, [byte]$k3)
    Reset-Keys
    Start-Sleep -Milliseconds 200
    [Win32.Input]::keybd_event($k1, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Win32.Input]::keybd_event($k2, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Win32.Input]::keybd_event($k3, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 200
    [Win32.Input]::keybd_event($k3, 0, 0x02, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Win32.Input]::keybd_event($k2, 0, 0x02, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [Win32.Input]::keybd_event($k1, 0, 0x02, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 400
}

function Send-CtrlWinD      { Send-Combo 0x11 0x5B 0x44 }
function Send-CtrlWinRight  { Send-Combo 0x11 0x5B 0x27 }
function Send-CtrlWinLeft   { Send-Combo 0x11 0x5B 0x25 }
function Send-CtrlWinF4     { Send-Combo 0x11 0x5B 0x73 }
function Send-WinShiftRight { Send-Combo 0x5B 0x10 0x27 }

function Get-WindowHandle {
    param($Process)
    try {
        $waited = 0
        while ($waited -lt 20) {
            $Process.Refresh()
            $hwnd = $Process.MainWindowHandle
            if ($hwnd -ne [IntPtr]::Zero) { return $hwnd }
            # Fallback: search all windows by PID
            $hwnd = [Win32.Input]::FindWindowByPid($Process.Id)
            if ($hwnd -ne [IntPtr]::Zero) { return $hwnd }
            Start-Sleep -Milliseconds 500; $waited++
        }
    } catch {}
    return [IntPtr]::Zero
}

function Move-WindowToDesktop2 {
    param($Process)
    $hwnd = Get-WindowHandle $Process
    if ($hwnd -eq [IntPtr]::Zero) { return $null }
    Write-Ok "  Activating PID $($Process.Id)..."
    [Win32.Input]::SwitchToThisWindow($hwnd, $true)
    Start-Sleep -Milliseconds 600
    Send-WinShiftRight
    Start-Sleep -Milliseconds 600
    return $hwnd
}

# ===== PHASE 1: Desktop cleanup =====
Write-Step "Cleaning up orphaned desktops..."
for ($i = 0; $i -lt 3; $i++) { Send-CtrlWinLeft }
Start-Sleep -Milliseconds 500
for ($i = 0; $i -lt 3; $i++) {
    Send-CtrlWinRight; Start-Sleep -Milliseconds 500
    Send-CtrlWinF4;    Start-Sleep -Milliseconds 800
}
for ($i = 0; $i -lt 3; $i++) { Send-CtrlWinLeft }
Start-Sleep -Milliseconds 500
Reset-Keys; Start-Sleep -Milliseconds 300

# ===== PHASE 2: Create streaming desktop =====
Write-Step "Creating streaming desktop..."
Send-CtrlWinD; Start-Sleep -Milliseconds 800
Write-Ok "Streaming desktop created"

# ===== PHASE 3: Launch apps =====
$script:streamDesktop = "Desktop 2"

# go-live (exe preferred, ps1 fallback)
$goLiveExe = "$env:USERPROFILE\Streaming\go-live.exe"
$goLivePs1 = "$env:USERPROFILE\Streaming\go-live.ps1"
if (Test-Path $goLiveExe) {
    Write-Step "Starting go-live.exe (CreateProcess)..."
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $goLiveExe
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = "$env:USERPROFILE\Streaming"
    $gp = [System.Diagnostics.Process]::Start($psi)
} elseif (Test-Path $goLivePs1) {
    Write-Step "Starting go-live.ps1 (PowerShell fallback)..."
    $gp = Start-Process -FilePath "powershell" -ArgumentList "-ExecutionPolicy Bypass -File `"$goLivePs1`"" -PassThru
} else {
    Write-Fail "go-live.exe and go-live.ps1 not found"; exit 1
}
Write-Ok "go-live PID $($gp.Id)"

# OBS
$obsRunning = Get-Process -Name "obs64" -ErrorAction SilentlyContinue
if ($obsRunning) {
    Write-Ok "OBS already running - moving to streaming desktop..."
    $obsHwnd = Move-WindowToDesktop2 $obsRunning[0]
} else {
    Write-Step "Launching OBS (CreateProcess)..."
    $obsDir = "${env:ProgramFiles}\obs-studio\bin\64bit"
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "$obsDir\obs64.exe"
    $psi.UseShellExecute = $false
    $psi.WorkingDirectory = $obsDir
    $obsProc = [System.Diagnostics.Process]::Start($psi)
    Write-Ok "OBS PID $($obsProc.Id)"
    $obsHwnd = Get-WindowHandle $obsProc
    if ($obsHwnd -eq [IntPtr]::Zero) {
        Write-Fail "  OBS didn't appear on streaming desktop - trying ShellExecute + move"
        $obsProc.Kill()
        Start-Sleep -Seconds 2
        $obsProc = Start-Process "$obsDir\obs64.exe" -PassThru
        $obsHwnd = Move-WindowToDesktop2 $obsProc
    }
}

# Spotify
$spotRunning = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
if ($spotRunning) {
    Write-Ok "Spotify already running - moving to streaming desktop..."
    $spotHwnd = Move-WindowToDesktop2 $spotRunning[0]
} else {
    Write-Step "Launching Spotify (ShellExecute)..."
    $spotExe = "${env:APPDATA}\Spotify\Spotify.exe"
    # Spotify has shell integration dependencies, try ShellExecute first
    $spotProc = Start-Process -FilePath $spotExe -PassThru
    $spotHwnd = Get-WindowHandle $spotProc
    if ($spotHwnd -ne [IntPtr]::Zero) {
        Write-Ok "  Spotify window appeared - moving to streaming desktop"
        $spotHwnd = Move-WindowToDesktop2 $spotProc
    } else {
        # If the Spotify launcher exits (spawns child), try finding existing spotify
        Write-Ok "  Spotify launcher spawned - finding window..."
        Start-Sleep -Seconds 5
        $spotReal = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue | Where-Object { $_.Id -ne $spotProc.Id }
        if ($spotReal) {
            $spotHwnd = Move-WindowToDesktop2 $spotReal[0]
        } else {
            Write-Fail "  Could not capture Spotify window"
        }
    }
}

# go-live window handle
$glHwnd = Get-WindowHandle $gp
if ($glHwnd -eq [IntPtr]::Zero) {
    Write-Fail "  go-live window not found - trying ShellExecute + move"
    $gp | Stop-Process -Force -ErrorAction SilentlyContinue
    $fallbackExe = if (Test-Path $goLiveExe) { $goLiveExe } else { $goLivePs1 }
    $gp = Start-Process -FilePath $fallbackExe -PassThru
    $glHwnd = Move-WindowToDesktop2 $gp
}

# ===== PHASE 4: Window layout =====
Write-Step "Applying layout..."
if ($obsHwnd -and $obsHwnd -ne [IntPtr]::Zero) {
    [Win32.Input]::MoveWindow($obsHwnd, 0, 0, 1720, 880, $true) | Out-Null
    Write-Ok "  OBS: 1720x880 @ (0,0)"
}
if ($glHwnd -and $glHwnd -ne [IntPtr]::Zero) {
    [Win32.Input]::MoveWindow($glHwnd, 1920-600, 1080-180, 600, 180, $true) | Out-Null
    Write-Ok "  go-live: 600x180 @ (1320,900)"
}
if ($spotHwnd -and $spotHwnd -ne [IntPtr]::Zero) {
    [Win32.Input]::ShowWindow($spotHwnd, [Win32.Input]::SW_MINIMIZE) | Out-Null
    Write-Ok "  Spotify minimized"
}

Write-Host ""
Write-Host "  Streaming is running on a dedicated virtual desktop." -ForegroundColor Gray
Write-Host "  All apps should now be on the streaming desktop." -ForegroundColor Gray
Write-Host "  Close the go-live window (Ctrl+C or X) to shut down." -ForegroundColor Gray
Write-Host ""

# ===== PHASE 5: Wait =====
try { $gp | Wait-Process -ErrorAction Stop } catch {}

# ===== PHASE 6: Cleanup =====
Write-Step "Shutting down..."
for ($i = 0; $i -lt 3; $i++) { Send-CtrlWinRight }
Start-Sleep -Milliseconds 500
Send-CtrlWinF4; Start-Sleep -Seconds 2
Write-Ok "Streaming desktop closed."
Start-Sleep -Seconds 2
