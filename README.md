# NSIS Notepad4 Installer

An NSIS script to create an installer for the Notepad4 binaries from https://github.com/zufuliu/notepad4

## Features

- Installs Notepad4 and matepath to Program Files
- Optional: Replace Windows Notepad with Notepad4 (Win10/Win11)
- Optional: **Fetch latest version (online)** — opt-in checkbox that queries GitHub for the latest release and downloads it if newer than the bundled version. No internet access occurs unless you select this option.
- Silent installation support

## Bundled Version

The current installer bundles **Notepad4 v26.01r5986** (English, x64).

## Usage

### Interactive Installation

Run the installer normally. By default it installs the bundled version offline. To check for a newer version, tick the "Fetch latest version (online)" checkbox on the components page.

### Silent Installation

```
notepad4_en_x64_v26.01r5986-install.exe /S /I=full
```

- `/S` — Silent mode (no GUI)
- `/I=full` — Full install (includes replacing Windows Notepad)
- `/I=minimal` — Minimal install (default, Notepad4 only)
- `/UPDATE` — Enable online fetch of the latest version (silent mode only)

## Uninstallation

The uninstaller removes Notepad4 files and registry entries. If Windows Notepad was replaced, it will be restored (on Win11, the Windows Notepad AppX package is re-registered).

## Building

Compile with [NSIS](https://nsis.sourceforge.io/):

```
makensis Notepad4_en_x64_v26.01r5986.nsi
```

Requires the `psexec.nsh` include file (provided in this repo) for PowerShell support.
