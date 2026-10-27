# Starts the two test instances the way the workspace expects them:
#   game\              -> profile Player  (FRSFastTest auto-continues)
#   game test player\  -> profile Test    (profile list waits, Down + Enter picks it)
#
#   .\launch-pair.ps1
#   .\launch-pair.ps1 -WaitSeconds 25
param(
    [int]$WaitSeconds = 16
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$hostDir = Join-Path $root 'game'
$guestDir = Join-Path $root 'game test player'
foreach ($d in @($hostDir, $guestDir)) {
    if (-not (Test-Path (Join-Path $d 'speed2.exe'))) { throw "no speed2.exe in $d" }
}

# The guest must wait at the profile list, otherwise it continues the last profile.
$guestFrs = Join-Path $guestDir 'scripts\FRSFastTest.ini'
if (Test-Path $guestFrs) {
    $text = [IO.File]::ReadAllText($guestFrs) -replace '(?m)^AutoContinue=.*$', 'AutoContinue=0'
    [IO.File]::WriteAllText($guestFrs, $text)
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Keys {
    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    public static void Tap(byte vk, byte scan) {
        keybd_event(vk, scan, 0, UIntPtr.Zero);
        System.Threading.Thread.Sleep(90);
        keybd_event(vk, scan, 2, UIntPtr.Zero);
    }
    public static void Enter() { Tap(0x0D, 0x1C); }
    public static void Down() { Tap(0x28, 0x50); }
}
'@

Get-Process speed2 -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host 'starting the host (profile Player)'
$host_ = Start-Process -FilePath (Join-Path $hostDir 'speed2.exe') -WorkingDirectory $hostDir -PassThru
Start-Sleep -Seconds 5

Write-Host 'starting the guest (profile Test)'
$guest = Start-Process -FilePath (Join-Path $guestDir 'speed2.exe') -WorkingDirectory $guestDir -PassThru

Start-Sleep -Seconds $WaitSeconds

Write-Host 'answering profile dialogs'
[Keys]::SetForegroundWindow($host_.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 600
[Keys]::Enter() | Out-Null
Start-Sleep -Seconds 2
[Keys]::SetForegroundWindow($guest.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 600
[Keys]::Down() | Out-Null
Start-Sleep -Milliseconds 700
[Keys]::Enter() | Out-Null
Start-Sleep -Seconds 12

$hostAlive = [bool](Get-Process -Id $host_.Id -ErrorAction SilentlyContinue)
$guestAlive = [bool](Get-Process -Id $guest.Id -ErrorAction SilentlyContinue)
Write-Host "host  $($host_.Id) alive=$hostAlive"
Write-Host "guest $($guest.Id) alive=$guestAlive"
$hostLog = Join-Path $hostDir "scripts\NFSU2Coop-$($host_.Id).log"
if (Test-Path $hostLog) {
    Get-Content $hostLog | Select-String -Pattern 'local model|slot 1 model|reloaded|applied' |
        Select-Object -Last 4 | ForEach-Object { $_.Line }
}
