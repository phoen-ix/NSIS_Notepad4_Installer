# NSIS Notepad4 Installer

An [NSIS](https://nsis.sourceforge.io/) script that builds a Windows installer for the
[Notepad4](https://github.com/zufuliu/notepad4) binaries (Notepad4 and matepath), with an option to
replace Windows Notepad.

<img src="docs/screenshots/installer-components.png" alt="Installer components page: Notepad4 preselected, Fetch latest version (online) and Replace Windows Editor unchecked, install type Minimal" width="499">

## Features

- Installs Notepad4 and matepath to `C:\Program Files\Notepad4`, with Start menu shortcuts and an
  Apps & Features entry
- Optional: **Replace Windows Editor** — every `notepad.exe` launch opens Notepad4 (Windows 10/11)
- Optional: **Fetch latest version (online)** — opt-in; queries GitHub for the latest Notepad4 release
  and installs it instead of the bundled one if its tag differs (see [Online update](#online-update)).
  No internet access happens unless you select this option.
- Silent installation support

## Bundled Version

The current installer bundles **Notepad4 v26.10r6392** (English, x64).

## Usage

### Interactive Installation

Run the installer. By default only Notepad4 is selected and the bundled version is installed offline.
The components page offers three install types:

| Install type | Notepad4 | Replace Windows Editor | Fetch latest version (online) |
|---|---|---|---|
| Minimal (preselected) | ✓ | | |
| Typical | ✓ | ✓ | |
| Full | ✓ | ✓ | ✓ |

### Silent Installation

```
notepad4_en_x64_v26.10r6392-install.exe /S /I=full
```

- `/S` — Silent mode (no GUI)
- `/I=full` — also replace Windows Notepad (does not enable the online fetch)
- `/I=minimal` — Notepad4 only (the default; any value other than `full` behaves the same)
- `/UPDATE` — enable the online fetch of the latest version (silent mode only)

Silent installs always go to `C:\Program Files\Notepad4` (`/D=` is ignored).

## Replace Windows Editor

The section registers `"C:\Program Files\Notepad4\Notepad4.exe" /z` as the `Debugger` for `notepad.exe`
under `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options`. On Windows 11 it
also removes the Windows Notepad app package (`Get-AppxPackage *Microsoft.WindowsNotepad* | Remove-AppxPackage`)
and adds the IFEO filter entries.

## Online update

The **Fetch latest version (online)** section (or `/UPDATE` in silent mode) extracts two PowerShell
helpers to the installer's temp directory and runs them:

1. [`check_update.ps1`](check_update.ps1) asks the GitHub API for the latest `zufuliu/notepad4` release
   (10 s timeout), picks the first asset matching `Notepad4_en_x64_*.zip` that is not an `HD` build,
   and writes `TagName`, `DownloadURL` and `Status` (`OK`, `NoAsset` or `Error`) to
   `%TEMP%\notepad4_update.ini`.
2. If the status is `OK` and the tag differs from `BUNDLED_VERSION`, the installer asks whether to
   download it (silent mode downloads without asking).
3. [`download_update.ps1`](download_update.ps1) downloads the zip (60 s timeout) to
   `%TEMP%\Notepad4_latest.zip`, extracts it to `%TEMP%\Notepad4_latest` (moving the contents of a
   top-level folder up), copies every `*.ini-default` to `*.ini`, and writes `OK` or `FAIL` to
   `%TEMP%\notepad4_download_status.txt`.
4. On `OK` the installer copies the downloaded `Notepad4.exe`, `matepath.exe`, the three `.ini` files
   and `License.txt` over the bundled ones and records the new tag as the version in Apps & Features.
   Otherwise it installs the bundled version (with a message in interactive mode).

The temp files are deleted afterwards.

## Uninstallation

The uninstaller removes the Notepad4 files, Start menu shortcuts and registry entries. If Windows Notepad
was replaced, it is restored (on Windows 11 the Windows Notepad app package is re-registered).

## Building

Compile with NSIS 3 (Windows, or Linux with `apt install nsis`):

```
makensis -WX Notepad4_en_x64_v26.10r6392.nsi
```

This writes `notepad4_en_x64_v26.10r6392-install.exe` next to the script (git-ignored). The script
includes [`psexec.nsh`](psexec.nsh) (PowerShell exec macros) and embeds the two update helpers and
[`Notepad4_Installer.ico`](Notepad4_Installer.ico). CI ([`ci.yml`](.github/workflows/ci.yml)) compiles it
with warnings as errors on every push and pull request.

## Updating to a new Notepad4 release

The version is part of the script name, the payload folder name and two defines; the installer file name
follows from them.

1. Download `Notepad4_en_x64_<version>.zip` (not the `HD` build) from the
   [Notepad4 releases](https://github.com/zufuliu/notepad4/releases) and check its SHA-256 against the
   release asset digest.
2. `git mv Notepad4_en_x64_<old> Notepad4_en_x64_<new>` and replace its six files with the zip's
   `Notepad4.exe`, `matepath.exe`, `License.txt` and the `*.ini-default` files renamed to `*.ini`
   (`Notepad4.ini`, `matepath.ini`, `Notepad4 DarkTheme.ini`). Give `License.txt` a UTF-8 BOM
   (`printf '\xef\xbb\xbf' | cat - License.txt > l && mv l License.txt`), otherwise the license page
   shows `Â©`; the screenshot tour checks it. If the release's file set changed, adjust the `File`,
   `CopyFiles` and `Delete` lines in the script.
3. `git mv Notepad4_en_x64_<old>.nsi Notepad4_en_x64_<new>.nsi` and update the defines at the top:
   `BUNDLED_VERSION` must equal the GitHub release tag exactly (e.g. `v26.10r6392`; the online fetch
   compares the two), `RELEASEVERSION` is `en_x64_<tag>`.
4. Replace every `<old>` in this README (`grep -n <old> README.md`): bundled version, silent-install and
   build output file names, build command, `License.txt` link.
5. `makensis -WX Notepad4_en_x64_<new>.nsi` must pass. The workflows find the script as
   `Notepad4_en_x64_*.nsi` and need no change.

## Screenshots

<img src="docs/screenshots/installer-license.png" alt="License agreement page showing the bundled Notepad4 license" width="499">
<img src="docs/screenshots/installer-directory.png" alt="Install location page with C:\Program Files\Notepad4 as the destination folder" width="499">
<img src="docs/screenshots/installer-complete.png" alt="Installation complete page with a full progress bar" width="499">

All installer and uninstaller pages: [docs/screenshots](docs/screenshots/README.md).

The images come from an automated tour: [`scripts/docs-screenshots.sh`](scripts/docs-screenshots.sh) compiles
the installer and runs [`scripts/docs-tour.ps1`](scripts/docs-tour.ps1), which clicks through every page via
UI Automation, checks each page's heading and captures the window. The tour really installs and uninstalls
Notepad4, so it only runs on throwaway Windows machines and refuses to start without `DOCS_TOUR_INSTALL=1`.

To regenerate: Actions → **Docs screenshots** → Run workflow, unzip the `docs-screenshots` artifact into
`docs/screenshots/`, run `oxipng -o 4 --strip safe docs/screenshots/*.png`, review the diff and commit.
On a disposable Windows VM with Git Bash and NSIS on `PATH`: `DOCS_TOUR_INSTALL=1 bash scripts/docs-screenshots.sh`.
CI runs the same tour as a render check on every push (artifact `tour-render-check`).

## License

The installer script is MIT-licensed ([LICENSE](LICENSE)). Notepad4 and matepath are distributed under
their own license, shown on the installer's first page
([`License.txt`](Notepad4_en_x64_v26.10r6392/License.txt)).
