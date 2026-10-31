# Dot-sourced by the e2e journeys: where a default install puts things, and the shared steps.
# The caller defines $Installer.
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot
$payload = (Get-Item "$repo\Notepad4_en_x64_*" | Where-Object PSIsContainer).FullName  # the bundled files
$version = [regex]::Match((Get-Content "$repo\Notepad4_en_x64_*.nsi" -Raw), '!define BUNDLED_VERSION "(.+?)"').Groups[1].Value
$payloadFiles = 'Notepad4.exe', 'matepath.exe', 'Notepad4.ini', 'matepath.ini', 'Notepad4 DarkTheme.ini', 'License.txt'
$dir = "$env:ProgramFiles\Notepad4"
$key = 'HKLM:\SOFTWARE\WOW6432Node\Notepad4'  # the 32-bit installer writes the 32-bit view
$arp = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Notepad4'
# What Windows reads when anything starts notepad.exe (a key WOW64 shares between both views).
$ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe'
$replaced = "`"$dir\Notepad4.exe`" /z"  # its Debugger value while Notepad4 replaces Windows Notepad

function Wait-For([scriptblock] $Probe, [string] $What, [int] $Seconds = 60) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  $last = $null
  do {
    try {
      $hit = & $Probe
      if ($hit) { return $hit }
    } catch {
      $last = $_  # elements vanish while a page changes; retry
    }
    Start-Sleep -Milliseconds 250
  } while ((Get-Date) -lt $deadline)
  throw "timed out after ${Seconds}s waiting for $What $last"
}

function Debugger { (Get-ItemProperty $ifeo -ErrorAction SilentlyContinue).Debugger }

function Assert-Equal($Got, $Want, [string] $What) {
  if ($Got -ne $Want) { throw "${What}: got '$Got', want '$Want'" }
}

function Install([string] $Arguments) {
  $p = Start-Process -FilePath $Installer -ArgumentList $Arguments -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "installer $Arguments exited with $($p.ExitCode)" }
}

# Like Apps & Features, but silent: Uninstall.exe copies itself to %TEMP% and returns at once,
# so it is done when the install folder is gone.
function Uninstall([string] $From = $dir) {
  $p = Start-Process -FilePath "$From\Uninstall.exe" -ArgumentList '/S' -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "Uninstall.exe /S exited with $($p.ExitCode)" }
  [void](Wait-For { -not (Test-Path $From) } "the uninstaller to remove $From")
}

# The bundled version: byte-identical to the payload folder, and so recorded in Apps & Features.
function Assert-Bundled([string] $When) {
  foreach ($f in $payloadFiles) {
    Assert-Equal (Get-FileHash "$dir\$f").Hash (Get-FileHash "$payload\$f").Hash "$When, $f"
  }
  Assert-Equal (Get-ItemProperty $arp).DisplayVersion $version "$When, DisplayVersion"
}

function Test([string] $Title, [scriptblock] $Body) {
  & $Body
  Write-Host "ok - $Title"
}
