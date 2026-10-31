# Dot-sourced by the screenshot tour and the interactive e2e journeys: finds NSIS wizard pages and
# message boxes through UI Automation and clicks their buttons with WM_COMMAND.
. "$PSScriptRoot\common.ps1"
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing, System.Windows.Forms
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
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, System.Text.StringBuilder text);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr hwnd, uint msg, IntPtr wParam, IntPtr lParam);
  [DllImport("user32.dll")] public static extern IntPtr GetParent(IntPtr hwnd);
  [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr hwnd);
}
'@

$UIA = [System.Windows.Automation.AutomationElement]
$Any = [System.Windows.Automation.Condition]::TrueCondition
$IsWindow = New-Object System.Windows.Automation.PropertyCondition($UIA::ControlTypeProperty, [System.Windows.Automation.ControlType]::Window)
$Children = [System.Windows.Automation.TreeScope]::Children
$Descendants = [System.Windows.Automation.TreeScope]::Descendants
# NSIS wizard buttons: Next / I Agree / Install / Uninstall / Close = 1, Cancel = 2; message box No = 7.
$IDOK = 1; $IDCANCEL = 2; $IDNO = 7

function Find-Text($Element, [string] $Prefix) {
  foreach ($e in $Element.FindAll($Descendants, $Any)) {
    if ($e.Current.Name.StartsWith($Prefix)) { return $e }
  }
}

function Find-Class($Element, [string] $Prefix) {
  foreach ($e in $Element.FindAll($Descendants, $Any)) {
    if ($e.Current.ClassName.StartsWith($Prefix)) { return $e }
  }
  throw "no $Prefix control"
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

# Waits for the message box of $Owner whose text starts with $Text and presses its button $Button,
# again until the box is gone (a click that arrives while the box is still opening gets lost).
function Answer($Owner, [string] $Text, [string] $Button, [int] $Seconds = 120) {
  $box = Wait-For { Find-Dialog $Owner $Text } "'$Text'" $Seconds
  $named = New-Object System.Windows.Automation.PropertyCondition($UIA::NameProperty, $Button)
  $id = [Win32]::GetDlgCtrlID((Get-Hwnd $box.FindFirst($Descendants, $named)))
  [void](Wait-For { Click $box $id; -not (Find-Dialog $Owner $Text) } "'$Text' to close" 30)
}

# Starts the wizard and clicks through to Install, keeping the preselected components (Minimal)
# or picking install type $Type. Returns the process and its main window.
function Start-Wizard([string] $Arguments, [ValidateSet('Typical', 'Minimal', 'Full')] [string] $Type) {
  $params = @{ FilePath = $Installer; PassThru = $true }
  if ($Arguments) { $params.ArgumentList = $Arguments }
  $p = Start-Process @params
  $null = $p.Handle  # keeps ExitCode readable after exit
  $w = Wait-For { Find-TopWindow { param($x) $x.Current.ProcessId -eq $p.Id } } 'the installer window'
  Wait-Page $w 'License Agreement'
  Click $w $IDOK
  Wait-Page $w 'Choose Components'
  if ($Type) {
    $combo = Get-Hwnd (Find-Class $w 'ComboBox')
    $index = [array]::IndexOf(@('Typical', 'Minimal', 'Full'), $Type)  # the InstType order
    [void][Win32]::SendMessage($combo, 0x014E, [IntPtr]$index, [IntPtr]::Zero)  # CB_SETCURSEL
    $notify = [IntPtr]((1 -shl 16) -bor [Win32]::GetDlgCtrlID($combo))      # CBN_SELCHANGE, as a click would send
    [void][Win32]::SendMessage([Win32]::GetParent($combo), 0x0111, $notify, $combo)
    Wait-Page $w $Type 10
  }
  Click $w $IDOK
  Wait-Page $w 'Choose Install Location'
  Click $w $IDOK
  Wait-Page $w 'Choose Start Menu Folder'
  Click $w $IDOK
  $p, $w
}

function Complete-Wizard($Process, $Window) {
  Wait-Page $Window 'Installation Complete' 180
  Click $Window $IDOK
  [void](Wait-For { $Process.HasExited } 'the installer to exit')
  Assert-Equal $Process.ExitCode 0 'installer exit code'
}
