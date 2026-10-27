#Requires -Version 7.0
<#
.SYNOPSIS
    Provisions the whole NFSU2 AI-modding workspace with one command.

.DESCRIPTION
    Everything lives inside this folder:
      toolchain\mingw32            i686 MinGW-w64 (space-free junction at C:\nfsu2-toolchain)
      toolchain\tools\x64dbg       x64dbg snapshot (32-bit debugger + headless)
      toolchain\tools\ghidra_*     Ghidra public build (decompiler)
      toolchain\cache              pinned archives, kept for offline reinstall
      references\                  study clones (nfsu2-web, recompiled, Unlimiter, ...)
      game\, game test player\     two test installs (not touched unless -InstallMods)

    Pins are SHA-256 checked; a wrong or missing file is re-downloaded. The script is
    idempotent: run it again after a reboot or a fresh clone.

.PARAMETER Force
    Re-download and re-extract every pinned tool.

.PARAMETER SkipBuild
    Do not build the mod and the bots.

.PARAMETER SkipTests
    Do not run the test suite.

.PARAMETER SkipReferences
    Do not clone the reference projects.

.PARAMETER InstallMods
    Copy the built ASI, its ini and FRSFastTest into the two game folders.

.EXAMPLE
    .\setup.ps1
    .\setup.ps1 -Force
    .\setup.ps1 -InstallMods
#>
param(
    [switch]$Force,
    [switch]$SkipBuild,
    [switch]$SkipTests,
    [switch]$SkipReferences,
    [switch]$InstallMods
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root    = $PSScriptRoot
$tc      = Join-Path $root 'toolchain'
$mingw   = Join-Path $tc 'mingw32'
$tools   = Join-Path $tc 'tools'
$cache   = Join-Path $tc 'cache'
$repo    = Join-Path $root 'nfsu2-coop'
$refs    = Join-Path $root 'references'

foreach ($d in @($tc, $tools, $cache, $refs)) { New-Item -ItemType Directory -Force $d | Out-Null }

function Write-Step($text) { Write-Host "`n== $text" -ForegroundColor Cyan }

function Test-Junction($path, $target) {
    if (-not (Test-Path $path)) { return $false }
    $item = Get-Item $path -Force
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return $false }
    return ((Get-Item $path -Force).Target -join '') -eq $target
}

function Ensure-Junction([string]$link, [string]$target) {
    if (Test-Junction $link $target) { Write-Host "  junction ok: $link"; return }
    if (Test-Path $link) { cmd /c rmdir $link 2>$null | Out-Null }
    cmd /c mklink /J $link $target | Out-Null
    Write-Host "  junction: $link -> $target"
}

function Get-Pinned([string]$url, [string]$dest, [string]$sha) {
    if ((Test-Path $dest) -and -not $Force) {
        if ((Get-FileHash $dest -Algorithm SHA256).Hash -eq $sha) {
            Write-Host "  cached $(Split-Path $dest -Leaf)"
            return
        }
        Write-Host "  cached file has the wrong hash, downloading again" -ForegroundColor Yellow
    }
    Write-Host "  download $url"
    & curl.exe -L --retry 3 --fail -o $dest $url
    if ($LASTEXITCODE -ne 0) { throw "download failed: $url" }
    $got = (Get-FileHash $dest -Algorithm SHA256).Hash
    if ($got -ne $sha) { throw "SHA-256 mismatch for $(Split-Path $dest -Leaf): $got" }
}

function Expand-Zip([string]$zip, [string]$dest, [string]$inner = '') {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if ($inner) {
        $staging = Join-Path $cache ("_x_" + [IO.Path]::GetFileNameWithoutExtension($zip))
        if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $staging)
        $src = Join-Path $staging $inner
        if (-not (Test-Path $src)) { throw "archive has no '$inner' folder" }
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        Move-Item $src $dest
        Remove-Item $staging -Recurse -Force
    } else {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        New-Item -ItemType Directory -Force $dest | Out-Null
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $dest)
    }
}

# ---------------------------------------------------------------- 1. MinGW ---
Write-Step 'MinGW-w64 i686 (compiler)'
$mingwZip = Join-Path $cache 'winlibs-i686.zip'
$mingwSha = '9353F386F7A678AB41B0746DB43211C4B6B8AB2811D2EDB289F0496711FB1C9B'
$mingwUrl = 'https://github.com/brechtsanders/winlibs_mingw/releases/download/16.2.0posix-23.1.3-14.0.0-ucrt-r3/winlibs-i686-posix-dwarf-gcc-16.2.0-llvm-23.1.3-mingw-w64ucrt-14.0.0-r3.zip'
if ($Force -or -not (Test-Path (Join-Path $mingw 'bin\g++.exe'))) {
    if ($Force -or -not (Test-Path $mingwZip)) { Get-Pinned $mingwUrl $mingwZip $mingwSha }
    Expand-Zip $mingwZip $mingw 'mingw32'
}
Write-Host ('  ' + (& (Join-Path $mingw 'bin\g++.exe') --version | Select-Object -First 1))
# GCC cannot run from a path with spaces, so it is reached through this junction.
Ensure-Junction 'C:\nfsu2-toolchain' $mingw

# --------------------------------------------------------------- 2. x64dbg ---
Write-Step 'x64dbg (32-bit debugger, headless)'
$x64 = Join-Path $tools 'x64dbg'
if ($Force -or -not (Test-Path (Join-Path $x64 'release\x32\x32dbg.exe'))) {
    $zip = Join-Path $cache 'x64dbg.zip'
    Get-Pinned 'https://github.com/x64dbg/x64dbg/releases/download/2026.05.27/snapshot_2026-05-27_12-11.zip' $zip `
        'D41966DFC5B435A372798245300CA0AB7BB8E48BDBF48512C6FB20FCCA427697'
    Expand-Zip $zip $x64
}
Write-Host '  release\x32\x32dbg.exe, release\x32\headless.exe'

# --------------------------------------------------------------- 3. Ghidra ---
Write-Step 'Ghidra (decompiler)'
$ghidra = Join-Path $tools 'ghidra_12.2_PUBLIC'
if ($Force -or -not (Test-Path (Join-Path $ghidra 'support\analyzeHeadless.bat'))) {
    $zip = Join-Path $cache 'ghidra.zip'
    Get-Pinned 'https://github.com/NationalSecurityAgency/ghidra/releases/download/Ghidra_12.2_build/ghidra_12.2_PUBLIC_20261016.zip' $zip `
        '2C2CD776DB3C1F6A097BA418922378AC3649CADD5E844A6F5F088AE628A7BE67'
    Expand-Zip $zip $tools 'ghidra_12.2_PUBLIC'
}
Write-Host '  support\analyzeHeadless.bat'

# ------------------------------------------------- 4. vendor deps, python ---
Write-Step 'Vendored libraries and Python test deps'
if (Test-Path (Join-Path $repo 'toolchain\install.ps1')) {
    & (Join-Path $repo 'toolchain\install.ps1') -Prefix $mingw -Only vendor | Out-Null
    & (Join-Path $repo 'toolchain\install.ps1') -Prefix $mingw -Only python | Out-Null
    Write-Host '  enet, minhook, imgui, pyyaml, pefile'
} else {
    Write-Host '  nfsu2-coop not found, skipped' -ForegroundColor Yellow
}

# ----------------------------------------------------------- 5. references ---
Write-Step 'Reference projects (study copies)'
if (-not $SkipReferences -and (Test-Path (Join-Path $repo 'tools\fetch-references.ps1'))) {
    & (Join-Path $repo 'tools\fetch-references.ps1')
} else {
    Write-Host '  skipped'
}

# --------------------------------------------------------------- 6. build ---
if (-not $SkipBuild) {
    Write-Step 'Build'
    if (Test-Path (Join-Path $repo 'build.ps1')) {
        $env:NFSU2_TOOLCHAIN = $mingw
        & (Join-Path $repo 'build.ps1')
    } else {
        Write-Host '  nfsu2-coop\build.ps1 missing' -ForegroundColor Yellow
    }
}

# --------------------------------------------------------------- 7. tests ---
if (-not $SkipTests) {
    Write-Step 'Tests'
    $runner = Join-Path $repo 'tests\run_all.ps1'
    if (Test-Path $runner) {
        $env:NFSU2_TOOLCHAIN = $mingw
        & $runner
    } else {
        Write-Host '  tests\run_all.ps1 missing' -ForegroundColor Yellow
    }
}

# ------------------------------------------------------------- 8. FRSFastTest ---
Write-Step 'FRSFastTest (boots straight into free roam)'
$frs = Join-Path $refs 'FRSFastTest'
$frsAsi = Join-Path $tc 'tools\FRSFastTest.asi'
if (Test-Path (Join-Path $frs 'games\nfsu2\FastTest.cpp')) {
    if ($Force -or -not (Test-Path $frsAsi)) {
        & (Join-Path $mingw 'bin\g++.exe') -std=c++17 -O2 -shared -o $frsAsi `
            (Join-Path $frs 'games\nfsu2\FastTest.cpp') -I (Join-Path $frs 'common') `
            -DWIN32_LEAN_AND_MEAN -DNOMINMAX -DUNICODE -D_UNICODE -luser32 -ladvapi32 `
            -static -static-libgcc -static-libstdc++
    }
    Write-Host "  $frsAsi"
} else {
    Write-Host '  reference clone missing, skipped' -ForegroundColor Yellow
}

# --------------------------------------------------------------- 9. mods in game ---
if ($InstallMods) {
    Write-Step 'Install the mod into both test installs'
    $asi = Join-Path $repo 'build\NFSU2Coop.asi'
    if (-not (Test-Path $asi)) { throw 'build\NFSU2Coop.asi missing, run without -SkipBuild' }
    foreach ($game in @((Join-Path $root 'game'), (Join-Path $root 'game test player'))) {
        if (-not (Test-Path $game)) { Write-Host "  $game missing" -ForegroundColor Yellow; continue }
        $scripts = Join-Path $game 'scripts'
        New-Item -ItemType Directory -Force $scripts | Out-Null
        Copy-Item $asi (Join-Path $scripts 'NFSU2Coop.asi') -Force
        if (-not (Test-Path (Join-Path $scripts 'nfsu2coop.ini'))) {
            Write-Host "  $scripts\nfsu2coop.ini missing (created on first run)" -ForegroundColor Yellow
        }
        if (Test-Path $frsAsi) {
            Copy-Item $frsAsi (Join-Path $scripts 'FRSFastTest.asi') -Force
            Copy-Item (Join-Path $frs 'games\nfsu2\FRSFastTest.ini') $scripts -Force
            Copy-Item (Join-Path $frs 'games\nfsu2\FRSFastTest-Tracks.txt') $scripts -Force
        }
        Write-Host "  $game"
    }
}

Write-Step 'Done'
Write-Host @"
  workspace   $root
  compiler    $mingw  (junction C:\nfsu2-toolchain)
  debugger    $x64\release\x32\x32dbg.exe
  decompiler  $ghidra\support\analyzeHeadless.bat
  mod         $repo
  references  $refs
  next        .\setup.ps1 -InstallMods   to put the ASI into the game folders
"@
