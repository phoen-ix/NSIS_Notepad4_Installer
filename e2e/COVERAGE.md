# E2E coverage

Every user-facing feature of the installer and uninstaller, and the test that drives it. The suite is
[`scripts/e2e.sh`](../scripts/e2e.sh). CI's `e2e` job runs it on windows-2022 and on windows-2025,
because the installer takes a different branch from Windows 11 (build 22000) on.

How the rows were extracted (2026-10-31, 26 hits):

```sh
grep -nE '^\s*(!insertmacro MUI_(UN)?PAGE_|!define MUI_ABORTWARNING|InstType |Section |MessageBox |\$\{GetOptions\}|\$\{If\} \$\{AtLeastWin11\})' Notepad4_en_x64_*.nsi
grep -nE 'Status=|"(OK|FAIL)"' check_update.ps1 download_update.ps1
```

The hits are the wizard pages, the install types, the command-line options, the sections with their
Windows 11 branches, the message boxes and the online-fetch outcomes. The rows below also include the
NSIS built-ins that the README documents (`/S`, `/D=`, the previous install folder), the uninstaller's
effects and the error paths. There are no roles: the installer runs elevated for everyone.

How the tests work:
- **The tour as the sweep.** [`scripts/docs-tour.ps1`](../scripts/docs-tour.ps1) drives the wizard and the
  uninstaller through UI Automation. It asserts each page heading and then takes a screenshot.
- **Silent journeys.** They check files, registry values and shortcuts, and that launching
  `notepad.exe` really opens Notepad4.
- **The online fetch.** It runs against a fixture build from `scripts/e2e.sh`. That build is identical
  except that `check_update.ps1` asks `http://127.0.0.1:$PORT_BASE/latest.json`. The local server
  answers in the GitHub API's shape and hosts the release zip.

**Totals: 51 rows. 48 ✅, 3 ❌ (2 × a, 1 × d).**

## Wizard pages and dialogs

| # | Item | Test | |
|---|---|---|---|
| 1 | License page with the bundled license text (`©` shows correctly) | `scripts/docs-tour.ps1 › installer-license` | ✅ |
| 2 | Cancel → abort warning → No returns to the wizard | `scripts/docs-tour.ps1 › installer-abort-warning` | ✅ |
| 3 | Cancel → abort warning → Yes quits, exit code 1, nothing installed | `e2e/test-silent.ps1 › Cancel, then Yes in the wizard quits without installing` | ✅ |
| 4 | Components page: Minimal preselected, full component names fit | `scripts/docs-tour.ps1 › installer-components` | ✅ |
| 5 | Install location page | `scripts/docs-tour.ps1 › installer-directory` | ✅ |
| 6 | Start menu folder page | `scripts/docs-tour.ps1 › installer-start-menu` | ✅ |
| 7 | Install progress and Installation Complete (exit code 0) | `scripts/docs-tour.ps1 › installer-complete` | ✅ |
| 8 | Uninstaller confirm page (as Apps & Features starts it, without `/S`) | `scripts/docs-tour.ps1 › uninstaller-confirm` | ✅ |
| 9 | Uninstaller progress and Uninstallation Complete | `scripts/docs-tour.ps1 › uninstaller-complete` | ✅ |
| 10 | English UI (the only language) | every `Wait-Page` heading in `scripts/docs-tour.ps1` | ✅ |

## Install types

| # | Item | Test | |
|---|---|---|---|
| 11 | Minimal (wizard default): Notepad4 only | `scripts/docs-tour.ps1 › installer-complete` | ✅ |
| 12 | Typical in the wizard: also replaces Windows Notepad | `e2e/test-update.ps1 › Typical in the wizard replaces Windows Notepad and ignores /UPDATE` | ✅ |
| 13 | Full in the wizard: also replaces Windows Notepad and fetches online | `e2e/test-update.ps1 › the wizard asks before installing a newer release; Yes installs it` | ✅ |

## Command line

| # | Item | Test | |
|---|---|---|---|
| 14 | `/S` alone installs Minimal | `e2e/test-silent.ps1 › /S installs Notepad4 only: files, registry, Start menu` | ✅ |
| 15 | `/S /I=minimal` | `e2e/test-silent.ps1 › /S /I=minimal leaves Windows Notepad alone` | ✅ |
| 16 | `/S /I=<other value>` behaves as minimal | `e2e/test-silent.ps1 › /S /I=typical leaves Windows Notepad alone` | ✅ |
| 17 | `/S /I=full` replaces Windows Notepad | `e2e/test-silent.ps1 › /S /I=full replaces Windows Notepad: notepad.exe opens Notepad4` | ✅ |
| 18 | `/S /I=full` without `/UPDATE` makes no network request | `e2e/test-update.ps1 › without /UPDATE the installer goes online not at all` | ✅ |
| 19 | `/S /UPDATE` turns on the online fetch | `e2e/test-update.ps1 › silent /UPDATE installs a newer release whose SHA-256 matches` | ✅ |
| 20 | `/UPDATE` is ignored in the wizard | `e2e/test-update.ps1 › Typical in the wizard replaces Windows Notepad and ignores /UPDATE` | ✅ |
| 21 | `/D=<folder with spaces>` | `e2e/test-install.ps1 › /D=` | ✅ |
| 22 | Without `/D=`, a reinstall goes to the previous install folder | `e2e/test-install.ps1 › reinstall without /D=` | ✅ |

## What an install writes (section Notepad4)

| # | Item | Test | |
|---|---|---|---|
| 23 | The six bundled files, byte-identical, plus `Uninstall.exe` | `e2e/test-silent.ps1 › /S installs Notepad4 only: files, registry, Start menu` | ✅ |
| 24 | `HKLM\SOFTWARE\Notepad4`: `Install_Dir`, `Start Menu Folder` | same | ✅ |
| 25 | Apps & Features entry: DisplayName, UninstallString, DisplayIcon, DisplayVersion, NoModify, NoRepair | same | ✅ |
| 26 | Start menu shortcuts `Notepad4.lnk` and `matepath.lnk` pointing at the installed exes | same | ✅ |

## Replace Windows Editor

| # | Item | Test | |
|---|---|---|---|
| 27 | Before Windows 11: IFEO `Debugger`, so `notepad.exe <file>` opens the file in Notepad4 | `e2e/test-silent.ps1 › /S /I=full replaces Windows Notepad: notepad.exe opens Notepad4` (windows-2022) | ✅ |
| 28 | Windows 11 branch (`${AtLeastWin11}`): the same, plus the filter keys | same (windows-2025, build 26100) | ✅ |
| 29 | Windows 11: removes the Windows Notepad app package | — | ❌ (a) needs a Windows 11 client edition with the Store Notepad app. GitHub's x64 Windows runners are Server editions and do not have the package. |

## Online fetch (section Fetch latest version)

| # | Item | Test | |
|---|---|---|---|
| 30 | Status OK, different tag, SHA-256 matches → installs the downloaded files and records the tag | `e2e/test-update.ps1 › silent /UPDATE installs a newer release whose SHA-256 matches` | ✅ |
| 31 | The zip's `*.ini-default` become `*.ini`, and a top-level folder in the zip is flattened | same | ✅ |
| 32 | The HD and AVX2 assets are skipped for the plain `en_x64` zip | same (they are listed first) | ✅ |
| 33 | SHA-256 differs → bundled version installed | `e2e/test-update.ps1 › silent /UPDATE installs the bundled version when the SHA-256 differs` | ✅ |
| 34 | No digest → rejected; a rejected zip is deleted | `e2e/test-download.ps1` (`SHA256=''` and wrong-digest cases) | ✅ |
| 35 | Same tag as bundled → no download | `e2e/test-update.ps1 › silent /UPDATE downloads nothing when the bundled version is the latest` | ✅ |
| 36 | Status NoAsset (no `en_x64` zip) → bundled | `e2e/test-update.ps1 › silent /UPDATE installs the bundled version when the release has no en_x64 zip` | ✅ |
| 37 | Status Error (the API fails) → bundled | `e2e/test-update.ps1 › silent /UPDATE installs the bundled version when the release API fails` | ✅ |
| 38 | The temp INI, status file, zip and extract folder are gone afterwards | every `e2e/test-update.ps1` journey (`Install-Fetching`) | ✅ |
| 39 | Message box "A newer version … is available" → Yes installs it | `e2e/test-update.ps1 › the wizard asks before installing a newer release; Yes installs it` | ✅ |
| 40 | The same message box → No installs the bundled version, with no download | `e2e/test-update.ps1 › No to the newer release installs the bundled version` | ✅ |
| 41 | Message box "Failed to download …" → bundled version | `e2e/test-update.ps1 › the wizard reports a failed download and installs the bundled version` | ✅ |

## Uninstaller

| # | Item | Test | |
|---|---|---|---|
| 42 | Removes the files and the install folder (also `Uninstall.exe`) | `e2e/test-silent.ps1 › the uninstaller removes the files, registry entries and Start menu folder` | ✅ |
| 43 | Removes the Start menu folder and shortcuts | same | ✅ |
| 44 | Removes `HKLM\SOFTWARE\Notepad4` and the Apps & Features entry | same | ✅ |
| 45 | Gives `notepad.exe` back to Windows Notepad (before Windows 11) | `e2e/test-silent.ps1 › the uninstaller gives notepad.exe back to Windows Notepad` (windows-2022) | ✅ |
| 46 | The same on the Windows 11 branch | same (windows-2025) | ✅ |
| 47 | Windows 11: re-registers the Windows Notepad app package | — | ❌ (a) same reason as row 29 |
| 48 | Keeps a `notepad.exe` replacement that another tool made | `e2e/test-silent.ps1 › the uninstaller keeps a notepad.exe replacement it did not make` | ✅ |
| 49 | Silent uninstall (`Uninstall.exe /S`) | every `Uninstall` call in `e2e/test-silent.ps1` and `e2e/test-update.ps1` | ✅ |
| 50 | Reinstall over an existing install | `e2e/test-install.ps1 › reinstall without /D=` | ✅ |

## Cross-cutting

| # | Item | Test | |
|---|---|---|---|
| 51 | UAC elevation prompt (`RequestExecutionLevel admin`) | — | ❌ (d) the consent prompt runs on the secure desktop, which UI Automation cannot reach. The runners' user is an administrator with the prompt turned off. |
