# Screenshot tour, called by scripts/docs-screenshots.sh (Windows PowerShell 5.1+).
# Starts the compiled installer, waits for each wizard page by its MUI header text (the
# assertion), captures the window to <OutDir>\<name>.png and clicks on. It installs Notepad4
# with the preselected minimal components (no online fetch, Windows Notepad untouched) and
# then runs the uninstaller, so the machine ends up as before.
param(
  [Parameter(Mandatory = $true)] [string] $Installer,
  [Parameter(Mandatory = $true)] [string] $OutDir
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class Win32 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr hwnd, int attr, out RECT rect, int size);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern bool SetWindowText(IntPtr hwnd, string text);
  [DllImport("user32.dll")] public static extern bool SystemParametersInfo(uint action, uint param, IntPtr value, uint winIni);
}
'@

$UIA = [System.Windows.Automation.AutomationElement]
$Any = [System.Windows.Automation.Condition]::TrueCondition
$IsWindow = New-Object System.Windows.Automation.PropertyCondition($UIA::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
$Children = [System.Windows.Automation.TreeScope]::Children
$Descendants = [System.Windows.Automation.TreeScope]::Descendants
# NSIS wizard buttons: Next / I Agree / Install / Uninstall / Close = 1, Cancel = 2; message box No = 7.
$IDOK = 1; $IDCANCEL = 2; $IDNO = 7

# No progress-bar glow: the same pixels on every run.
[void][Win32]::SystemParametersInfo(0x1043, 0, [IntPtr]::Zero, 2)  # SPI_SETCLIENTAREAANIMATION = off
[void][Win32]::SetCursorPos(0, 0)

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

function Find-Text($Element, [string] $Prefix) {
  foreach ($e in $Element.FindAll($Descendants, $Any)) {
    if ($e.Current.Name.StartsWith($Prefix)) { return $e }
  }
}

function Find-TopWindow([scriptblock] $Match) {
  foreach ($w in $UIA::RootElement.FindAll($Children, $IsWindow)) {
    if (& $Match $w) { return $w }
  }
}

# A message box owned by $Owner (UIA lists it under the owner or under the desktop).
function Find-Dialog($Owner, [string] $Prefix) {
  $candidates = @($Owner.FindAll($Children, $IsWindow)) + @($UIA::RootElement.FindAll($Children, $IsWindow))
  foreach ($w in $candidates) {
    if ($w.Current.ProcessId -eq $Owner.Current.ProcessId -and
        $w.Current.NativeWindowHandle -ne $Owner.Current.NativeWindowHandle -and
        (Find-Text $w $Prefix)) { return $w }
  }
}

function Get-Hwnd($Element) { [IntPtr]$Element.Current.NativeWindowHandle }

function Click($Window, [int] $Id) {
  [void][Win32]::PostMessage((Get-Hwnd $Window), 0x0111, [IntPtr]$Id, [IntPtr]::Zero)  # WM_COMMAND
}

function Wait-Page($Window, [string] $Text, [int] $Seconds = 60) {
  try {
    [void](Wait-For { Find-Text $Window $Text } "'$Text'" $Seconds)
  } catch {
    $names = foreach ($e in $Window.FindAll($Descendants, $Any)) { $e.Current.Name }
    Write-Host "window shows: $(($names | Where-Object { $_ }) -join ' | ')"
    throw
  }
}

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
