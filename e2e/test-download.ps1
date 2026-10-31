# download_update.ps1 check (Windows PowerShell 5.1+, Python on PATH), run by scripts/e2e.sh: the online
# fetch extracts the release zip only when its SHA-256 matches the digest check_update.ps1 wrote,
# and deletes a rejected zip.
# Serves a fixture zip from 127.0.0.1 and points %TEMP% at a scratch folder.
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) 'notepad4-download-test'
Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
$serve = (New-Item -ItemType Directory "$root\serve").FullName
$env:TEMP = (New-Item -ItemType Directory "$root\temp").FullName  # inherited by download_update.ps1
Set-Content "$serve\Notepad4.ini-default" 'fixture'
Compress-Archive "$serve\Notepad4.ini-default" "$serve\release.zip"
$good = (Get-FileHash "$serve\release.zip" -Algorithm SHA256).Hash.ToLower()
$url = 'http://127.0.0.1:8765/release.zip'

function Fetch([string] $Sha256) {
  Remove-Item "$env:TEMP\*" -Recurse -Force
  '[Update]', 'TagName=v0.0r0', "DownloadURL=$url", "SHA256=$Sha256", 'Status=OK' |
    Out-File "$env:TEMP\notepad4_update.ini" -Encoding ASCII
  powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\..\download_update.ps1"
  (Get-Content "$env:TEMP\notepad4_download_status.txt").Trim()
}

$server = Start-Process python -ArgumentList '-m http.server 8765 --bind 127.0.0.1' -WorkingDirectory $serve -PassThru -WindowStyle Hidden
try {
  $deadline = (Get-Date).AddSeconds(30)
  while ($true) {
    try { Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 2 | Out-Null; break }
    catch { if ((Get-Date) -gt $deadline) { throw "fixture server not up: $_" }; Start-Sleep -Milliseconds 250 }
  }

  if ((Fetch $good) -ne 'OK' -or -not (Test-Path "$env:TEMP\Notepad4_latest\Notepad4.ini")) {
    throw 'the zip with the matching SHA-256 was not extracted'
  }
  foreach ($bad in ('0' * 64), '') {
    if ((Fetch $bad) -ne 'FAIL' -or (Test-Path "$env:TEMP\Notepad4_latest") -or (Test-Path "$env:TEMP\Notepad4_latest.zip")) {
      throw "the zip was accepted with SHA256='$bad'"
    }
  }
  Write-Host 'online download: only a zip with the release SHA-256 is used'
} finally {
  Stop-Process -Id $server.Id -Force
}
