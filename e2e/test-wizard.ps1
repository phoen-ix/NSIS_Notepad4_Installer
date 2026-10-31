# Wizard journeys (Windows PowerShell 5.1+, admin), run by scripts/e2e.sh on a throwaway machine:
# what the install location and Start menu pages do with the user's choices, and Cancel in the
# uninstaller.
param([Parameter(Mandatory = $true)] [string] $Installer)
. "$PSScriptRoot\uia.ps1"
$programs = [Environment]::GetFolderPath('Programs')  # the installing user's Start menu
$shell = New-Object -ComObject WScript.Shell

Test 'the wizard installs into the folder and Start menu folder typed in; the uninstaller removes both' {
  $folder = 'C:\Notepad4 Wizard e2e'
  $menu = "$programs\Editors e2e"
  $p, $w = Start-Wizard -Folder $folder -MenuFolder 'Editors e2e'
  Complete-Wizard $p $w
  if (Test-Path $dir) { throw "installed to $dir" }
  $app = Get-ItemProperty $key
  Assert-Equal $app.Install_Dir $folder 'Install_Dir'
  Assert-Equal $app.'Start Menu Folder' 'Editors e2e' 'Start Menu Folder'
  Assert-Equal (Get-ItemProperty $arp).UninstallString "`"$folder\Uninstall.exe`"" 'UninstallString'
  foreach ($exe in 'Notepad4', 'matepath') {
    Assert-Equal $shell.CreateShortcut("$menu\$exe.lnk").TargetPath "$folder\$exe.exe" "$exe.lnk target"
  }
  Uninstall $folder
  foreach ($path in $menu, $key, $arp) { if (Test-Path $path) { throw "the uninstall left $path" } }
}

Test 'Do not create shortcuts installs Notepad4 without a Start menu folder' {
  $p, $w = Start-Wizard -NoShortcuts
  Complete-Wizard $p $w
  Assert-Bundled 'no shortcuts'
  if (Test-Path "$programs\Notepad4") { throw "created $programs\Notepad4" }
  Assert-Equal (Get-ItemProperty $key).'Start Menu Folder' $null 'Start Menu Folder'
  Uninstall
  foreach ($path in $key, $arp) { if (Test-Path $path) { throw "the uninstall left $path" } }
}

Test 'Cancel in the uninstaller keeps Notepad4 installed' {
  Install '/S'
  Start-Process -FilePath "$dir\Uninstall.exe"  # it re-launches itself from %TEMP%: find it by title
  $isUninstaller = { param($x) $x.Current.Name -like 'Notepad4 Uninstall*' }
  $un = Wait-For { Find-TopWindow $isUninstaller } 'the uninstaller window'
  Wait-Page $un 'Uninstall Notepad4'
  Click $un $IDCANCEL
  [void](Wait-For { -not (Find-TopWindow $isUninstaller) } 'the uninstaller to close')
  Assert-Bundled 'after Cancel in the uninstaller'
  foreach ($path in "$dir\Uninstall.exe", "$programs\Notepad4\Notepad4.lnk", $key) {
    if (-not (Test-Path $path)) { throw "Cancel in the uninstaller removed $path" }
  }
  Uninstall
}
