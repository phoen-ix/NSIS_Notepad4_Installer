# Install-type journeys (Windows PowerShell 5.1+, admin), run by scripts/e2e.sh on a throwaway
# machine: what /S and /I= install (files, registry, Start menu, the Windows Notepad replacement),
# that the uninstaller takes all of it away again, and that quitting the wizard installs nothing.
param([Parameter(Mandatory = $true)] [string] $Installer)
. "$PSScriptRoot\uia.ps1"
$menu = Join-Path ([Environment]::GetFolderPath('Programs')) 'Notepad4'  # the installing user's Start menu
$doc = "$env:TEMP\notepad4-e2e.txt"
Set-Content $doc 'e2e'
$shell = New-Object -ComObject WScript.Shell
# The installer's ${AtLeastWin11} branch (build 22000 on) sets IFEO filter keys instead of UseFilter=0.
$win11 = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').CurrentBuildNumber -ge 22000
function FilterFullPath([int] $Index) { (Get-ItemProperty "$ifeo\$Index" -ErrorAction SilentlyContinue).FilterFullPath }
function UseFilter { (Get-ItemProperty $ifeo -ErrorAction SilentlyContinue).UseFilter }

# Opens $doc with notepad.exe; returns the process name of the editor that shows it.
function Open-WithNotepad {
  $before = @(Get-Process Notepad4, notepad -ErrorAction SilentlyContinue | ForEach-Object Id)
  Start-Process notepad.exe -ArgumentList "`"$doc`""
  $editor = Wait-For {
    Get-Process Notepad4, notepad -ErrorAction SilentlyContinue |
      Where-Object { $_.Id -notin $before -and $_.MainWindowTitle -like '*notepad4-e2e*' } | Select-Object -First 1
  } 'an editor window showing the file' 30
  Stop-Process -Id $editor.Id -Force
  $editor.ProcessName
}

Test '/S installs Notepad4 only: files, registry, Start menu' {
  Install '/S'
  Assert-Bundled '/S'
  if (-not (Test-Path "$dir\Uninstall.exe")) { throw "no $dir\Uninstall.exe" }
  $app = Get-ItemProperty $key
  Assert-Equal $app.Install_Dir $dir 'Install_Dir'
  Assert-Equal $app.'Start Menu Folder' 'Notepad4' 'Start Menu Folder'
  $entry = Get-ItemProperty $arp
  Assert-Equal $entry.DisplayName 'Notepad4' 'DisplayName'
  Assert-Equal $entry.UninstallString "`"$dir\Uninstall.exe`"" 'UninstallString'
  Assert-Equal $entry.DisplayIcon "$dir\Notepad4.exe" 'DisplayIcon'
  Assert-Equal $entry.NoModify 1 'NoModify'
  Assert-Equal $entry.NoRepair 1 'NoRepair'
  foreach ($exe in 'Notepad4', 'matepath') {
    Assert-Equal $shell.CreateShortcut("$menu\$exe.lnk").TargetPath "$dir\$exe.exe" "$exe.lnk target"
  }
  Assert-Equal (Debugger) $null 'notepad.exe Debugger'
}

Test 'the uninstaller removes the files, registry entries and Start menu folder' {
  Uninstall
  foreach ($p in $menu, $key, $arp) { if (Test-Path $p) { throw "the uninstall left $p" } }
}

foreach ($type in 'minimal', 'typical') {  # every value but full means minimal
  Test "/S /I=$type leaves Windows Notepad alone" {
    Install "/S /I=$type"
    Assert-Equal (Debugger) $null "notepad.exe Debugger after /I=$type"
    Uninstall
  }
}

Test '/S /I=full replaces Windows Notepad: notepad.exe opens Notepad4' {
  Install '/S /I=full'
  Assert-Equal (Open-WithNotepad) 'Notepad4' 'editor started by notepad.exe'
  Assert-Equal (Debugger) $replaced 'notepad.exe Debugger'
  if ($win11) {
    foreach ($i in 0..2) { Assert-Equal (FilterFullPath $i) "$dir\Notepad4.exe" "notepad.exe\$i FilterFullPath" }
  } else {
    Assert-Equal (UseFilter) 0 'notepad.exe UseFilter'
  }
}

Test 'the uninstaller gives notepad.exe back to Windows Notepad' {
  Uninstall
  Assert-Equal (Debugger) $null 'notepad.exe Debugger after the uninstall'
  if ($win11) {
    foreach ($i in 0..2) { Assert-Equal (FilterFullPath $i) $null "notepad.exe\$i FilterFullPath after the uninstall" }
  } else {
    Assert-Equal (UseFilter) $null 'notepad.exe UseFilter after the uninstall'
  }
  Assert-Equal (Open-WithNotepad) 'notepad' 'editor started by notepad.exe after the uninstall'
}

Test 'the uninstaller keeps a notepad.exe replacement it did not make' {
  Install '/S'
  if (-not (Test-Path $ifeo)) { New-Item $ifeo | Out-Null }
  Set-ItemProperty $ifeo '(default)' 'C:\Other\editor.exe'
  Set-ItemProperty $ifeo Debugger '"C:\Other\editor.exe"'
  try {
    Uninstall
    Assert-Equal (Debugger) '"C:\Other\editor.exe"' 'foreign notepad.exe Debugger after the uninstall'
  } finally {
    Remove-ItemProperty $ifeo Debugger, '(default)' -ErrorAction SilentlyContinue
  }
}

Test 'Cancel, then Yes in the wizard quits without installing' {
  $p = Start-Process -FilePath $Installer -PassThru
  $null = $p.Handle
  $w = Wait-For { Find-TopWindow { param($x) $x.Current.ProcessId -eq $p.Id } } 'the installer window'
  Wait-Page $w 'License Agreement'
  Click $w $IDCANCEL
  Answer $w 'Are you sure you want to quit' 'Yes'
  [void](Wait-For { $p.HasExited } 'the installer to quit')
  Assert-Equal $p.ExitCode 1 'exit code after Cancel'  # NSIS: 1 = cancelled by the user
  foreach ($path in $dir, $key, $arp) { if (Test-Path $path) { throw "the cancelled install left $path" } }
}
