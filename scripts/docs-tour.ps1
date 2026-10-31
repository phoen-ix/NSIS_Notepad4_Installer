# Screenshot tour (Windows PowerShell 5.1+), called by scripts/docs-screenshots.sh and, as the page sweep, by scripts/e2e.sh.
# Starts the compiled installer, waits for each wizard page by its MUI header text (the
# assertion), captures the window to <OutDir>\<name>.png and clicks on. It installs Notepad4
# with the preselected minimal components (no online fetch, Windows Notepad untouched) and
# then runs the uninstaller, so the machine ends up as before.
param(
  [Parameter(Mandatory = $true)] [string] $Installer,
  [Parameter(Mandatory = $true)] [string] $OutDir
)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\..\e2e\uia.ps1"

# No progress-bar glow: the same pixels on every run.
[void][Win32]::SystemParametersInfo(0x1043, 0, [IntPtr]::Zero, 2)  # SPI_SETCLIENTAREAANIMATION = off
[void][Win32]::SetCursorPos(0, 0)

# PrintWindow renders the window itself (immune to overlapping windows); crop the invisible
# resize border to the visible frame.
function Save-Shot($Window, [string] $Name) {
  $h = Get-Hwnd $Window
  [void][Win32]::SetForegroundWindow($h)
  Start-Sleep -Milliseconds 700  # let the page finish painting
  $win = New-Object Win32+RECT
  $frame = New-Object Win32+RECT
  if (-not [Win32]::GetWindowRect($h, [ref] $win)) { throw "GetWindowRect failed for $Name" }
  if ([Win32]::DwmGetWindowAttribute($h, 9, [ref] $frame, 16) -ne 0) { throw "no DWM frame for $Name" }  # EXTENDED_FRAME_BOUNDS
  $full = New-Object System.Drawing.Bitmap ($win.Right - $win.Left), ($win.Bottom - $win.Top)
  $g = [System.Drawing.Graphics]::FromImage($full)
  $hdc = $g.GetHdc()
  $ok = [Win32]::PrintWindow($h, $hdc, 2)  # PW_RENDERFULLCONTENT
  $g.ReleaseHdc($hdc)
  $g.Dispose()
  if (-not $ok) { throw "PrintWindow failed for $Name" }
  $crop = New-Object System.Drawing.Rectangle ($frame.Left - $win.Left), ($frame.Top - $win.Top), ($frame.Right - $frame.Left), ($frame.Bottom - $frame.Top)
  $shot = $full.Clone($crop, $full.PixelFormat)
  $shot.Save((Join-Path $OutDir "$Name.png"), [System.Drawing.Imaging.ImageFormat]::Png)
  $shot.Dispose()
  $full.Dispose()
  Write-Host "shot $Name.png"
}

# ---- installer
$proc = Start-Process -FilePath $Installer -PassThru
$null = $proc.Handle  # keeps ExitCode readable after exit
$main = Wait-For { Find-TopWindow { param($w) $w.Current.ProcessId -eq $proc.Id } } 'the installer window'

Wait-Page $main 'License Agreement'
# License.txt is UTF-8; without a BOM a Windows-built installer decodes it as cp1252 (mojibake for the (c) sign).
$license = Get-Hwnd (Find-Class $main 'RichEdit')
$text = New-Object System.Text.StringBuilder 65536
[void][Win32]::SendMessage($license, 0x000D, [IntPtr]$text.Capacity, $text)  # WM_GETTEXT
if (-not $text.ToString().Contains("Copyright $([char]0xA9) 2011")) { throw "license page lacks 'Copyright (c) 2011' (License.txt needs a UTF-8 BOM)" }
Save-Shot $main 'installer-license'

$quit = 'Are you sure you want to quit'
Click $main $IDCANCEL
$box = Wait-For { Find-Dialog $main $quit } 'the abort warning'
Save-Shot $box 'installer-abort-warning'
Click $box $IDNO
[void](Wait-For { -not (Find-Dialog $main $quit) } 'the abort warning to close')

Click $main $IDOK
Wait-Page $main 'Choose Components'
Wait-Page $main 'Minimal' 10  # .onInit preselects Notepad4 only (UIA does not expose the tree items)
# The longest component name must fit the tree (+ checkbox, indent, border); it used to be cut off.
$tree = Find-Class $main 'SysTreeView32'
$need = [System.Windows.Forms.TextRenderer]::MeasureText('Fetch latest version (online)', [System.Drawing.SystemFonts]::DialogFont).Width + 40
$width = $tree.Current.BoundingRectangle.Width
if ($width -lt $need) { throw "components tree is ${width}px wide, 'Fetch latest version (online)' needs ${need}px" }
Save-Shot $main 'installer-components'

Click $main $IDOK
Wait-Page $main 'Choose Install Location'
# Free disk space differs per machine; pin it like a fixed clock.
$free = Find-Text $main 'Space available: '
if (-not $free) { throw "directory page lacks 'Space available'" }
[void][Win32]::SetWindowText((Get-Hwnd $free), 'Space available: 100.0 GB')
Save-Shot $main 'installer-directory'

Click $main $IDOK
Wait-Page $main 'Choose Start Menu Folder'
# The folder list mirrors the machine's Start menu (runner images change it); pin it to standard folders.
$folders = Get-Hwnd (Find-Class $main 'ListBox')
[void][Win32]::SendMessage($folders, 0x0184, [IntPtr]::Zero, [IntPtr]::Zero)  # LB_RESETCONTENT
foreach ($f in 'Accessibility', 'Accessories', 'Administrative Tools', 'Startup', 'System Tools', 'Windows PowerShell') {
  [void][Win32]::SendMessage($folders, 0x0180, [IntPtr]::Zero, (New-Object System.Text.StringBuilder $f))  # LB_ADDSTRING
}
Save-Shot $main 'installer-start-menu'

Click $main $IDOK
Wait-Page $main 'Installation Complete' 180
Save-Shot $main 'installer-complete'
Click $main $IDOK
[void](Wait-For { $proc.HasExited } 'the installer to exit')
if ($proc.ExitCode -ne 0) { throw "installer exited with $($proc.ExitCode)" }

# ---- uninstaller (it re-launches itself from %TEMP%, so find its window by title)
$uninstaller = Join-Path $env:ProgramFiles 'Notepad4\Uninstall.exe'
if (-not (Test-Path $uninstaller)) { throw "the install did not create $uninstaller" }
Start-Process -FilePath $uninstaller
$isUninstaller = { param($w) $w.Current.Name -like 'Notepad4 Uninstall*' }
$un = Wait-For { Find-TopWindow $isUninstaller } 'the uninstaller window'

Wait-Page $un 'Uninstall Notepad4'
Save-Shot $un 'uninstaller-confirm'

Click $un $IDOK
Wait-Page $un 'Uninstallation Complete' 120
Save-Shot $un 'uninstaller-complete'
Click $un $IDOK
[void](Wait-For { -not (Find-TopWindow $isUninstaller) } 'the uninstaller to close')
[void](Wait-For { -not (Test-Path $uninstaller) } 'the uninstaller to remove itself')
