$ErrorActionPreference = "SilentlyContinue"
$iniFile = "$env:TEMP\notepad4_update.ini"
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/zufuliu/notepad4/releases/latest" -TimeoutSec 10
    $tagName = $response.tag_name
    $asset = $response.assets | Where-Object { $_.name -match "Notepad4_en_x64_.*\.zip$" -and $_.name -notmatch "HD" } | Select-Object -First 1
    if ($asset) {
        $downloadUrl = $asset.browser_download_url
        "[Update]" | Out-File $iniFile -Encoding ASCII
        "TagName=$tagName" | Out-File $iniFile -Append -Encoding ASCII
        "DownloadURL=$downloadUrl" | Out-File $iniFile -Append -Encoding ASCII
        "Status=OK" | Out-File $iniFile -Append -Encoding ASCII
    } else {
        "[Update]" | Out-File $iniFile -Encoding ASCII
        "Status=NoAsset" | Out-File $iniFile -Append -Encoding ASCII
    }
} catch {
    "[Update]" | Out-File $iniFile -Encoding ASCII
    "Status=Error" | Out-File $iniFile -Append -Encoding ASCII
}
