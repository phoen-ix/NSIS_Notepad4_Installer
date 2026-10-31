# Silent-install check (Windows PowerShell 5.1+, admin), run by scripts/e2e.sh on a throwaway machine:
# /D= picks the install folder, a later install without /D= stays in that folder
# (InstallDirRegKey), and the uninstaller removes it again.
param([Parameter(Mandatory = $true)] [string] $Installer)
$ErrorActionPreference = 'Stop'
$dir = 'C:\Notepad4 Test'
$key = 'HKLM:\SOFTWARE\WOW6432Node\Notepad4'  # the 32-bit installer writes the 32-bit view

function Run([string] $Exe, [string] $Arguments) {
  $p = Start-Process -FilePath $Exe -ArgumentList $Arguments -Wait -PassThru
  if ($p.ExitCode -ne 0) { throw "$Exe $Arguments exited with $($p.ExitCode)" }
}

function Assert-InstalledInDir([string] $When) {
  if (-not (Test-Path "$dir\Notepad4.exe")) { throw "${When}: Notepad4.exe is not in $dir" }
  if (Test-Path "$env:ProgramFiles\Notepad4") { throw "${When}: installed to $env:ProgramFiles\Notepad4" }
  $got = (Get-ItemProperty $key).Install_Dir
  if ($got -ne $dir) { throw "${When}: Install_Dir is '$got', expected '$dir'" }
}

Run $Installer "/S /D=$dir"  # /D= must come last, unquoted
Assert-InstalledInDir '/D='
Run $Installer '/S'
Assert-InstalledInDir 'reinstall without /D='

Run "$dir\Uninstall.exe" "/S _?=$dir"  # _?= runs it in place and waits
if (Test-Path "$dir\Notepad4.exe") { throw "uninstall left $dir\Notepad4.exe" }
if (Test-Path $key) { throw "uninstall left $key" }
Remove-Item $dir -Recurse -Force
Write-Host 'silent install: /D= and the previous install folder are honoured'
