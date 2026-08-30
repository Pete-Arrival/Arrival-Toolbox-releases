# Arrival Toolbox — Releases

This repository publishes built releases of **Arrival Toolbox**, a Windows provisioning/debloat/
tweak/cleanup tool for Arrival Consulting. It contains no source code — just the self-contained
`.exe` and its SHA256 checksum, one release per version.

**Latest download** (always the current version, no login required):

```
https://github.com/Pete-Arrival/Arrival-Toolbox-releases/releases/latest/download/ArrivalToolbox.exe
```

**One-liner bootstrap** (downloads, verifies the checksum, then launches it):

```powershell
irm https://raw.githubusercontent.com/Pete-Arrival/Arrival-Toolbox-releases/main/bootstrap.ps1 | iex
```

Each release also has a `.sha256` checksum file alongside the `.exe`, so you can verify a download
matches what was actually built before running it.

Not signed yet — Windows SmartScreen will show an "unrecognised app" warning on first run.

This is an automated mirror; releases are published here by CI whenever a new version is tagged in
the (private) source repository.
