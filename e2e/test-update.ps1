# Online-update journeys (Windows PowerShell 5.1+, admin, Python on PATH), run by scripts/e2e.sh:
# $Installer is the fixture build whose check_update.ps1 asks http://127.0.0.1:$Port/latest.json
# instead of the GitHub API. A local server plays the release API and the download host; each
# journey publishes a different answer and checks what a silent /UPDATE install, or the wizard
# with the Full install type, makes of it.
param(
  [Parameter(Mandatory = $true)] [string] $Installer,
  [Parameter(Mandatory = $true)] [int] $Port
)
. "$PSScriptRoot\uia.ps1"
$root = Join-Path ([IO.Path]::GetTempPath()) 'notepad4-update-test'
Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
$serve = (New-Item -ItemType Directory "$root\serve").FullName
$log = "$root\server.log"
$url = "http://127.0.0.1:$Port"
$tag = 'v99.1r1'
$zip = "Notepad4_en_x64_$tag.zip"
$temps = 'notepad4_update.ini', 'notepad4_download_status.txt', 'Notepad4_latest.zip', 'Notepad4_latest' |
  ForEach-Object { Join-Path $env:TEMP $_ }

# A release zip like upstream's: *.ini-default instead of *.ini, here inside a top-level folder.
$release = (New-Item -ItemType Directory "$root\Notepad4_en_x64_$tag").FullName
foreach ($f in 'Notepad4.exe', 'matepath.exe', 'License.txt', 'Notepad4.ini-default', 'matepath.ini-default', 'Notepad4 DarkTheme.ini-default') {
  Set-Content "$release\$f" "$tag $f"
}
Compress-Archive $release "$serve\$zip"
$digest = 'sha256:' + (Get-FileHash "$serve\$zip").Hash.ToLower()

# latest.json as the GitHub API answers it; the HD and AVX2 builds come first and must be skipped.
function Publish([string] $Tag, [string] $Digest, [string[]] $Assets = @("Notepad4_HD_en_x64_$Tag.zip", "Notepad4_en_AVX2_$Tag.zip", "Notepad4_en_x64_$Tag.zip")) {
  $list = @(foreach ($a in $Assets) { @{ name = $a; browser_download_url = "$url/$a"; digest = $Digest } })
  ConvertTo-Json @{ tag_name = $Tag; assets = $list } -Depth 3 | Set-Content "$serve\latest.json" -Encoding ASCII
}

function Requests { @(Select-String -Path $log -Pattern '"GET (\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value }) }

# Runs $Install (silent: the installer arguments; else a wizard script); returns the paths the
# installer fetched. The temp files must be gone afterwards.
function Install-Fetching($Install) {
  $seen = (Requests).Count
  if ($Install -is [scriptblock]) { & $Install } else { Install $Install }
  foreach ($t in $temps) { if (Test-Path $t) { throw "the install left $t" } }
  (Requests | Select-Object -Skip $seen) -join ' '
}

# The wizard with the Full install type: answers the update question with $Answer (Yes or No; and
# OKs the failure message when $Fails), then finishes.
function Wizard-Full([string] $Answer, [switch] $Fails) {
  $p, $w = Start-Wizard -Type Full
  Answer $w "A newer version of Notepad4 is available: $tag" $Answer
  if ($Fails) { Answer $w 'Failed to download the latest version' 'OK' }
  Complete-Wizard $p $w
}

$server = Start-Process python -ArgumentList "-u -m http.server $Port --bind 127.0.0.1" -WorkingDirectory $serve `
  -NoNewWindow -PassThru -RedirectStandardError $log
try {
  [void](Wait-For { try { Invoke-WebRequest "$url/" -UseBasicParsing -TimeoutSec 2 | Out-Null; $true } catch { $false } } 'the fixture server' 30)

  Test 'silent /UPDATE installs a newer release whose SHA-256 matches' {
    Publish $tag $digest
    Assert-Equal (Install-Fetching '/S /UPDATE') "/latest.json /$zip" 'requests'
    foreach ($f in $payloadFiles) {
      $from = if ($f -like '*.ini') { "$f-default" } else { $f }
      Assert-Equal (Get-Content "$dir\$f") "$tag $from" $f
    }
    Assert-Equal (Get-ItemProperty $arp).DisplayVersion $tag 'DisplayVersion'
    Uninstall
  }

  Test 'silent /UPDATE installs the bundled version when the SHA-256 differs' {
    Publish $tag ('sha256:' + '0' * 64)
    Assert-Equal (Install-Fetching '/S /UPDATE') "/latest.json /$zip" 'requests'
    Assert-Bundled 'SHA-256 mismatch'
    Uninstall
  }

  Test 'silent /UPDATE downloads nothing when the bundled version is the latest' {
    Publish $version $digest
    Assert-Equal (Install-Fetching '/S /UPDATE') '/latest.json' 'requests'
    Assert-Bundled 'same tag'
    Uninstall
  }

  Test 'silent /UPDATE installs the bundled version when the release has no en_x64 zip' {
    Publish $tag $digest @("Notepad4_HD_en_x64_$tag.zip", "Notepad4_en_AVX2_$tag.zip")
    Assert-Equal (Install-Fetching '/S /UPDATE') '/latest.json' 'requests'
    Assert-Bundled 'no asset'
    Uninstall
  }

  Test 'silent /UPDATE installs the bundled version when the release API fails' {
    Remove-Item "$serve\latest.json"  # 404
    Assert-Equal (Install-Fetching '/S /UPDATE') '/latest.json' 'requests'
    Assert-Bundled 'API error'
    Uninstall
  }

  Test 'without /UPDATE the installer goes online not at all' {
    Publish $tag $digest
    Assert-Equal (Install-Fetching '/S /I=full') '' 'requests'
    Assert-Bundled 'no /UPDATE'
    Uninstall
  }

  Test 'the wizard asks before installing a newer release; Yes installs it' {
    Publish $tag $digest
    Assert-Equal (Install-Fetching { Wizard-Full Yes }) "/latest.json /$zip" 'requests'
    Assert-Equal (Get-Content "$dir\Notepad4.exe") "$tag Notepad4.exe" 'Notepad4.exe'
    Assert-Equal (Get-ItemProperty $arp).DisplayVersion $tag 'DisplayVersion'
    Assert-Equal (Debugger) $replaced 'notepad.exe Debugger (Full replaces Windows Notepad)'
    Uninstall
  }

  Test 'No to the newer release installs the bundled version' {
    Publish $tag $digest
    Assert-Equal (Install-Fetching { Wizard-Full No }) '/latest.json' 'requests'
    Assert-Bundled 'No'
    Uninstall
  }

  Test 'the wizard reports a failed download and installs the bundled version' {
    Publish $tag ('sha256:' + '0' * 64)
    Assert-Equal (Install-Fetching { Wizard-Full Yes -Fails }) "/latest.json /$zip" 'requests'
    Assert-Bundled 'failed download'
    Uninstall
  }

  Test 'Typical in the wizard replaces Windows Notepad and ignores /UPDATE' {
    Publish $tag $digest
    Assert-Equal (Install-Fetching { $p, $w = Start-Wizard '/UPDATE' Typical; Complete-Wizard $p $w }) '' 'requests'
    Assert-Bundled 'wizard with /UPDATE'
    Assert-Equal (Debugger) $replaced 'notepad.exe Debugger after Typical'
    Uninstall
  }

  Test 'Fetch latest version ticked by hand (Custom) installs the newer release and leaves Windows Notepad alone' {
    Publish $tag $digest
    $wizard = { $p, $w = Start-Wizard -Fetch; Answer $w "A newer version of Notepad4 is available: $tag" Yes; Complete-Wizard $p $w }
    Assert-Equal (Install-Fetching $wizard) "/latest.json /$zip" 'requests'
    Assert-Equal (Get-ItemProperty $arp).DisplayVersion $tag 'DisplayVersion'
    Assert-Equal (Debugger) $null 'notepad.exe Debugger'
    Uninstall
  }
} finally {
  Stop-Process -Id $server.Id -Force -ErrorAction SilentlyContinue
}
