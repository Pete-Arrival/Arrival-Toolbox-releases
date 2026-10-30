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

# Streamed download rather than `Invoke-WebRequest -OutFile`. On PowerShell 5.1 - which is what
# ships with Windows, so it is what this one-liner almost always runs under - Invoke-WebRequest
# buffers the entire response in memory before it writes anything to disk, and repaints its
# progress bar on every read. On a payload this size that is the difference between a download
# that tracks the line speed and one that takes minutes and looks like a hang.
$downloadedViaStream = $false
try {
    # System.Net.Http is not loaded by default on 5.1; on 7+ it already is.
    if (-not ('System.Net.Http.HttpClient' -as [type])) {
        Add-Type -AssemblyName System.Net.Http
    }

    $httpClient = New-Object System.Net.Http.HttpClient
    # HttpClient's default 100s timeout covers the whole transfer, not just the response headers,
    # and 100s is not enough for a self-contained .NET exe over a client site's connection.
    $httpClient.Timeout = [TimeSpan]::FromMinutes(30)
    try {
        # ResponseHeadersRead hands control back as soon as the headers land, so the body flows
        # through the copy loop below instead of being buffered up first. That is the actual fix.
        $response = $httpClient.GetAsync($exeUrl, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        try {
            $response.EnsureSuccessStatusCode() | Out-Null
            $totalBytes = $response.Content.Headers.ContentLength
            $source = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
            $destination = [System.IO.File]::Create($exePath)
            try {
                $buffer = New-Object -TypeName byte[] -ArgumentList (1MB)
                $copied = 0L
                $reportedAt = 0L
                while (($read = $source.Read($buffer, 0, $buffer.Length)) -gt 0) {
                    $destination.Write($buffer, 0, $read)
                    $copied += $read
                    # One console update per 8 MiB, deliberately not one per read - reporting per
                    # read is exactly what makes Invoke-WebRequest's own progress bar expensive.
                    if (($copied - $reportedAt) -ge 8MB) {
                        $reportedAt = $copied
                        $copiedMiB = [math]::Round($copied / 1MB, 1)
                        if ($totalBytes) {
                            $totalMiB = [math]::Round($totalBytes / 1MB, 1)
                            $percent = [math]::Floor(($copied / $totalBytes) * 100)
                            Write-Host "`r  $copiedMiB MiB of $totalMiB MiB ($percent%)   " -NoNewline
                        }
                        else {
                            Write-Host "`r  $copiedMiB MiB   " -NoNewline
                        }
                    }
                }
            }
            finally {
                # Released before the catch below can delete the partial file: a finally runs as
                # the exception propagates outward, so the handle is gone by the time we get there.
                $destination.Dispose()
                $source.Dispose()
            }
            Write-Host ''
            $downloadedViaStream = $true
        }
        finally {
            $response.Dispose()
        }
    }
    finally {
        $httpClient.Dispose()
    }
}
catch {
    # Constrained Language Mode blocks New-Object and direct .NET member access outright, so on a
    # locked-down estate the streamed path cannot run at all - but Invoke-WebRequest is a cmdlet
    # and still can. Falling back keeps those machines working instead of trading them for speed.
    Write-Host ''
    Write-Host "Streamed download unavailable ($($_.Exception.Message)); falling back to Invoke-WebRequest..."
    Remove-Item -Path $exePath -Force -ErrorAction SilentlyContinue
}

if (-not $downloadedViaStream) {
    # Silencing the progress bar is worth several-fold on its own on 5.1, since it is repainted on
    # every read and each repaint is a full console write. Restore the caller's setting afterwards:
    # `iex` means this is running in their session, not in a child process.
    $previousProgressPreference = $ProgressPreference
    $ProgressPreference = 'SilentlyContinue'
    try {
        Invoke-WebRequest -Uri $exeUrl -OutFile $exePath -UseBasicParsing
    }
    finally {
        $ProgressPreference = $previousProgressPreference
    }
}

Write-Host 'Verifying checksum...'
# GitHub serves release assets as application/octet-stream regardless of file extension, so
# Invoke-WebRequest's .Content comes back as a byte[] here, not a string - decode it explicitly
# rather than relying on -UseBasicParsing to guess a text encoding from the response headers.
$hashBytes = (Invoke-WebRequest -Uri $hashUrl -UseBasicParsing).Content
$publishedHashLine = [System.Text.Encoding]::UTF8.GetString($hashBytes)
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
