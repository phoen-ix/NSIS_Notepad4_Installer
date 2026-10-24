# Screenshots

Every page of the installer and uninstaller wizard, captured by the automated tour
(`scripts/docs-screenshots.sh`, see the main [README](../../README.md#screenshots)).

## License agreement

The first page shows the Notepad4 license bundled with the release; **I Agree** continues.

<img src="installer-license.png" alt="Installer license agreement page with the Notepad4 license text" width="499">

## Cancel confirmation

Cancel asks before quitting the setup.

<img src="installer-abort-warning.png" alt="Message box asking whether to quit Notepad4 Setup" width="340">

## Components

Notepad4 (with matepath) is always installed. **Replace Windows Editor** and **Fetch latest version
(online)** are opt-in; the install type list switches between Minimal (preselected), Typical and Full.

<img src="installer-components.png" alt="Components page with Notepad4 checked and the two optional sections unchecked" width="499">

## Install location

Defaults to the previous install's folder, else `C:\Program Files\Notepad4`. (The tour pins the machine-dependent "Space available" to 100.0 GB.)

<img src="installer-directory.png" alt="Install location page with the destination folder C:\Program Files\Notepad4" width="499">

## Start menu folder

Folder for the Notepad4 and matepath shortcuts; the list shows the machine's existing Start menu folders
(the tour pins it to a few standard Windows folders).

<img src="installer-start-menu.png" alt="Start menu folder page with Notepad4 as the folder name" width="499">

## Installation complete

<img src="installer-complete.png" alt="Installation complete page with a full progress bar" width="499">

## Uninstall

The uninstaller (Apps & Features → Notepad4) confirms the folder before removing it.

<img src="uninstaller-confirm.png" alt="Uninstall page showing the folder Notepad4 is removed from" width="499">

## Uninstall complete

If Windows Notepad was replaced, it has been restored at this point.

<img src="uninstaller-complete.png" alt="Uninstallation complete page" width="499">
