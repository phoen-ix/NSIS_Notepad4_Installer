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
NSIS built-ins that the README documents (`/S`, `/D=`, the previous install folder), the controls on
each page (component tree, folder fields, "Do not create shortcuts", Cancel), the uninstaller's effects
and the error paths. There are no roles: the installer runs elevated for everyone.

How the tests work:
- **The tour as the sweep.** [`scripts/docs-tour.ps1`](../scripts/docs-tour.ps1) drives the wizard and the
  uninstaller through UI Automation. It asserts each page heading and then takes a screenshot.
- **Silent and wizard journeys.** They check files, registry values and shortcuts, and that launching
  `notepad.exe` really opens Notepad4. The wizard journeys fill in the pages through UI Automation and
  window messages, as a user's clicks and keys would.
- **Test names.** `e2e/<script> › <title>` is a `Test '<title>'` block in that script, and `e2e.log` shows
  `ok - <title>` for each one that passed. In `test-install.ps1` and `test-download.ps1` it is the step
  that the script's closing line confirms. `scripts/docs-tour.ps1 › <name>` is the page shot `<name>.png`.
- **The online fetch.** It runs against a fixture build from `scripts/e2e.sh`. That build is identical
  except that `check_update.ps1` asks `http://127.0.0.1:$PORT_BASE/latest.json`. The local server
  answers in the GitHub API's shape and hosts the release zip.

**Totals: 57 rows. 47 ✅, 10 ❌ (2 × a, 1 × d, 7 × e).**

**TODO (e), about 30 min:** rows 5, 7, 9, 10, 13, 16 and 49 have journeys in `e2e/test-wizard.ps1` and at the
end of `e2e/test-update.ps1`, but they have not run on Windows yet. Their first CI run decides: fix what
it shows, then turn the rows ✅. The ✅ rows passed in CI run 41163611794 on windows-2022 and windows-2025.

## Wizard pages and dialogs

| # | Item | Test | |
|---|---|---|---|
| 1 | License page with the bundled license text (`©` shows correctly) | `scripts/docs-tour.ps1 › installer-license` | ✅ |
| 2 | Cancel → abort warning → No returns to the wizard | `scripts/docs-tour.ps1 › installer-abort-warning` | ✅ |
| 3 | Cancel → abort warning → Yes quits, exit code 1, nothing installed | `e2e/test-silent.ps1 › Cancel, then Yes in the wizard quits without installing` | ✅ |
| 4 | Components page: Minimal preselected, full component names fit | `scripts/docs-tour.ps1 › installer-components` | ✅ |
| 5 | Ticking a component in the tree by hand: install type Custom, and the ticked section runs | `e2e/test-update.ps1 › Fetch latest version ticked by hand (Custom) installs the newer release and leaves Windows Notepad alone` | ❌ (e) written, not run yet (TODO below) |
| 6 | Install location page | `scripts/docs-tour.ps1 › installer-directory` | ✅ |
| 7 | A folder (with spaces) typed on the install location page: files, `Install_Dir`, Apps & Features and shortcut targets use it | `e2e/test-wizard.ps1 › the wizard installs into the folder and Start menu folder typed in; the uninstaller removes both` | ❌ (e) written, not run yet (TODO below) |
| 8 | Start menu folder page | `scripts/docs-tour.ps1 › installer-start-menu` | ✅ |
| 9 | A Start menu folder typed in: shortcuts there, recorded as `Start Menu Folder` | same | ❌ (e) written, not run yet (TODO below) |
| 10 | "Do not create shortcuts": no Start menu folder, no `Start Menu Folder` value | `e2e/test-wizard.ps1 › the wizard default (Minimal) with Do not create shortcuts installs Notepad4 only, without a Start menu folder` | ❌ (e) written, not run yet (TODO below) |
| 11 | Install progress and Installation Complete (exit code 0) | `scripts/docs-tour.ps1 › installer-complete` | ✅ |
| 12 | Uninstaller confirm page (as Apps & Features starts it, without `/S`) | `scripts/docs-tour.ps1 › uninstaller-confirm` | ✅ |
| 13 | Cancel on the uninstaller confirm page keeps the install | `e2e/test-wizard.ps1 › Cancel in the uninstaller keeps Notepad4 installed` | ❌ (e) written, not run yet (TODO below) |
| 14 | Uninstaller progress and Uninstallation Complete | `scripts/docs-tour.ps1 › uninstaller-complete` | ✅ |
| 15 | English UI (the only language) | every `Wait-Page` heading in `scripts/docs-tour.ps1` | ✅ |

## Install types

| # | Item | Test | |
|---|---|---|---|
| 16 | Minimal (wizard default): Notepad4 only, Windows Notepad untouched, nothing fetched | `scripts/docs-tour.ps1 › installer-components` (Minimal preselected), `e2e/test-wizard.ps1 › the wizard default (Minimal) with Do not create shortcuts installs Notepad4 only, without a Start menu folder` | ❌ (e) written, not run yet (TODO below) |
| 17 | Typical in the wizard: also replaces Windows Notepad | `e2e/test-update.ps1 › Typical in the wizard replaces Windows Notepad and ignores /UPDATE` | ✅ |
| 18 | Full in the wizard: also replaces Windows Notepad and fetches online | `e2e/test-update.ps1 › the wizard asks before installing a newer release; Yes installs it` | ✅ |

## Command line

| # | Item | Test | |
|---|---|---|---|
| 19 | `/S` alone installs Minimal | `e2e/test-silent.ps1 › /S installs Notepad4 only: files, registry, Start menu` | ✅ |
| 20 | `/S /I=minimal` | `e2e/test-silent.ps1 › /S /I=minimal leaves Windows Notepad alone` | ✅ |
| 21 | `/S /I=<other value>` behaves as minimal | `e2e/test-silent.ps1 › /S /I=typical leaves Windows Notepad alone` | ✅ |
| 22 | `/S /I=full` replaces Windows Notepad | `e2e/test-silent.ps1 › /S /I=full replaces Windows Notepad: notepad.exe opens Notepad4` | ✅ |
| 23 | `/S /I=full` without `/UPDATE` makes no network request | `e2e/test-update.ps1 › without /UPDATE the installer goes online not at all` | ✅ |
| 24 | `/S /UPDATE` turns on the online fetch | `e2e/test-update.ps1 › silent /UPDATE installs a newer release whose SHA-256 matches` | ✅ |
| 25 | `/UPDATE` is ignored in the wizard | `e2e/test-update.ps1 › Typical in the wizard replaces Windows Notepad and ignores /UPDATE` | ✅ |
| 26 | `/D=<folder with spaces>` | `e2e/test-install.ps1 › /D=` | ✅ |
| 27 | Without `/D=`, a reinstall goes to the previous install folder | `e2e/test-install.ps1 › reinstall without /D=` | ✅ |

## What an install writes (section Notepad4)

| # | Item | Test | |
|---|---|---|---|
| 28 | The six bundled files, byte-identical, plus `Uninstall.exe` | `e2e/test-silent.ps1 › /S installs Notepad4 only: files, registry, Start menu` | ✅ |
| 29 | `HKLM\SOFTWARE\Notepad4`: `Install_Dir`, `Start Menu Folder` | same | ✅ |
| 30 | Apps & Features entry: DisplayName, UninstallString, DisplayIcon, DisplayVersion, NoModify, NoRepair | same | ✅ |
| 31 | Start menu shortcuts `Notepad4.lnk` and `matepath.lnk` pointing at the installed exes | same | ✅ |

## Replace Windows Editor

| # | Item | Test | |
|---|---|---|---|
| 32 | Before Windows 11: IFEO `Debugger` and `UseFilter` = 0, so `notepad.exe <file>` opens the file in Notepad4 | `e2e/test-silent.ps1 › /S /I=full replaces Windows Notepad: notepad.exe opens Notepad4` (windows-2022) | ✅ |
| 33 | Windows 11 branch (`${AtLeastWin11}`): `Debugger`, and `FilterFullPath` under `notepad.exe\0`, `\1`, `\2` instead of `UseFilter` | same (windows-2025, build 26100) | ✅ |
| 34 | Windows 11: removes the Windows Notepad app package | — | ❌ (a) needs a Windows 11 client edition with the Store Notepad app. GitHub's x64 Windows runners are Server editions and do not have the package. |

## Online fetch (section Fetch latest version)

| # | Item | Test | |
|---|---|---|---|
| 35 | Status OK, different tag, SHA-256 matches → installs the downloaded files and records the tag | `e2e/test-update.ps1 › silent /UPDATE installs a newer release whose SHA-256 matches` | ✅ |
| 36 | The zip's `*.ini-default` become `*.ini`, and a top-level folder in the zip is flattened | same | ✅ |
| 37 | The HD and AVX2 assets are skipped for the plain `en_x64` zip | same (they are listed first) | ✅ |
| 38 | SHA-256 differs → bundled version installed | `e2e/test-update.ps1 › silent /UPDATE installs the bundled version when the SHA-256 differs` | ✅ |
| 39 | No digest → rejected; a rejected zip is deleted | `e2e/test-download.ps1` (`SHA256=''` and wrong-digest cases) | ✅ |
| 40 | Same tag as bundled → no download | `e2e/test-update.ps1 › silent /UPDATE downloads nothing when the bundled version is the latest` | ✅ |
| 41 | Status NoAsset (no `en_x64` zip) → bundled | `e2e/test-update.ps1 › silent /UPDATE installs the bundled version when the release has no en_x64 zip` | ✅ |
| 42 | Status Error (the API fails) → bundled | `e2e/test-update.ps1 › silent /UPDATE installs the bundled version when the release API fails` | ✅ |
| 43 | The temp INI, status file, zip and extract folder are gone afterwards | every `e2e/test-update.ps1` journey (`Install-Fetching`) | ✅ |
| 44 | Message box "A newer version … is available" → Yes installs it | `e2e/test-update.ps1 › the wizard asks before installing a newer release; Yes installs it` | ✅ |
| 45 | The same message box → No installs the bundled version, with no download | `e2e/test-update.ps1 › No to the newer release installs the bundled version` | ✅ |
| 46 | Message box "Failed to download …" → bundled version | `e2e/test-update.ps1 › the wizard reports a failed download and installs the bundled version` | ✅ |

## Uninstaller

| # | Item | Test | |
|---|---|---|---|
| 47 | Removes the files and the install folder (also `Uninstall.exe`) | `e2e/test-silent.ps1 › the uninstaller removes the files, registry entries and Start menu folder` | ✅ |
| 48 | Removes the Start menu folder and shortcuts | same | ✅ |
| 49 | Removes the Start menu folder chosen in the wizard (read back from `Start Menu Folder`) | `e2e/test-wizard.ps1 › the wizard installs into the folder and Start menu folder typed in; the uninstaller removes both` | ❌ (e) written, not run yet (TODO below) |
| 50 | Removes `HKLM\SOFTWARE\Notepad4` and the Apps & Features entry | `e2e/test-silent.ps1 › the uninstaller removes the files, registry entries and Start menu folder` | ✅ |
| 51 | Gives `notepad.exe` back to Windows Notepad (before Windows 11): `Debugger` and `UseFilter` gone | `e2e/test-silent.ps1 › the uninstaller gives notepad.exe back to Windows Notepad` (windows-2022) | ✅ |
| 52 | The same on the Windows 11 branch: `Debugger` and the three `FilterFullPath` values gone | same (windows-2025) | ✅ |
| 53 | Windows 11: re-registers the Windows Notepad app package | — | ❌ (a) same reason as row 34 |
| 54 | Keeps a `notepad.exe` replacement that another tool made | `e2e/test-silent.ps1 › the uninstaller keeps a notepad.exe replacement it did not make` | ✅ |
| 55 | Silent uninstall (`Uninstall.exe /S`) | every `Uninstall` call in `e2e/test-silent.ps1` and `e2e/test-update.ps1` | ✅ |
| 56 | Reinstall over an existing install | `e2e/test-install.ps1 › reinstall without /D=` | ✅ |

## Cross-cutting

| # | Item | Test | |
|---|---|---|---|
| 57 | UAC elevation prompt (`RequestExecutionLevel admin`) | — | ❌ (d) the consent prompt runs on the secure desktop, which UI Automation cannot reach. The runners' user is an administrator with the prompt turned off. |
