$ErrorActionPreference = "SilentlyContinue"
$iniFile = "$env:TEMP\notepad4_update.ini"
$statusFile = "$env:TEMP\notepad4_download_status.txt"
$zipPath = "$env:TEMP\Notepad4_latest.zip"
$extractDir = "$env:TEMP\Notepad4_latest"
try {
    # Read download URL from the INI file
    $url = (Get-Content $iniFile | Where-Object { $_ -match "^DownloadURL=" }) -replace "^DownloadURL=", ""
    if (-not $url) { throw "No download URL found" }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
    Invoke-WebRequest -Uri $url -OutFile $zipPath -TimeoutSec 60
    Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force

    # If zip extracted into a subdirectory, move contents up
    $subDir = Get-ChildItem $extractDir -Directory | Select-Object -First 1
    if ($subDir) {
        Get-ChildItem $subDir.FullName | Move-Item -Destination $extractDir -Force
        Remove-Item $subDir.FullName -Force
    }

    # Copy .ini-default files to .ini
    Get-ChildItem $extractDir -Filter "*.ini-default" | ForEach-Object {
        $newName = $_.Name -replace "\.ini-default$", ".ini"
        Copy-Item $_.FullName (Join-Path $extractDir $newName) -Force
    }

    "OK" | Out-File $statusFile -Encoding ASCII
} catch {
    "FAIL" | Out-File $statusFile -Encoding ASCII
}
