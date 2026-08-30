# Arrival Toolbox bootstrap (PLAN.md §4's "convenience bootstrap" - same muscle memory as
# `irm <url> | iex`, but this script does not *contain* the tool: it downloads the built exe from
# the latest GitHub Release, verifies its SHA256 against the checksum published alongside it, and
# only then launches it. That's the whole point versus piping arbitrary script content into a
# shell - the actual payload is a discrete, checksummed file you can inspect before it runs.
#
# Usage:
#   irm https://raw.githubusercontent.com/Pete-Arrival/Arrival-Toolbox-releases/main/bootstrap.ps1 | iex
#
# On a machine with Constrained Language Mode or restrictive AppLocker script rules, this bootstrap
# itself may be blocked - download the exe directly from the Releases page as a fallback:
#   https://github.com/Pete-Arrival/Arrival-Toolbox-releases/releases/latest

$ErrorActionPreference = 'Stop'

$exeUrl = 'https://github.com/Pete-Arrival/Arrival-Toolbox-releases/releases/latest/download/ArrivalToolbox.exe'
$hashUrl = 'https://github.com/Pete-Arrival/Arrival-Toolbox-releases/releases/latest/download/ArrivalToolbox.exe.sha256'

$tempDir = Join-Path $env:TEMP 'ArrivalToolbox'
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
$exePath = Join-Path $tempDir 'ArrivalToolbox.exe'

Write-Host 'Downloading Arrival Toolbox...'
Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing

Write-Host 'Verifying checksum...'
$publishedHashLine = (Invoke-WebRequest -Uri $hashUrl -UseBasicParsing).Content
$expectedHash = $publishedHashLine.Trim().Split(' ')[0].Trim().ToUpperInvariant()
$actualHash = (Get-FileHash -Path $exePath -Algorithm SHA256).Hash.ToUpperInvariant()

if ($actualHash -ne $expectedHash) {
    Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
    # No explicit `exit` here - this script runs via `iex` in the caller's own shell, not a child
    # process, so `exit` would close their entire PowerShell session. $ErrorActionPreference =
    # 'Stop' already makes Write-Error a terminating error, which is enough to stop this script.
    Write-Error "Checksum mismatch - expected $expectedHash but got $actualHash. The download may be corrupted or tampered with; refusing to run it. Deleted the downloaded file."
}

Write-Host 'Checksum verified. Launching Arrival Toolbox (you will be prompted for admin elevation)...'
Start-Process -FilePath $exePath
