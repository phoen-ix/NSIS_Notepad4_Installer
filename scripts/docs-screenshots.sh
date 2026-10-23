#!/usr/bin/env bash
# Screenshot tour of the installer and uninstaller wizards -> PNGs in ${1:-docs/screenshots}.
# Windows only (Git Bash, makensis + Windows PowerShell on PATH): compiles the installer,
# then scripts/docs-tour.ps1 clicks through every page via UI Automation. The tour really
# installs Notepad4 (Program Files, HKLM, Start menu) and uninstalls it again, so it refuses
# to run without DOCS_TOUR_INSTALL=1. Meant for throwaway machines: the docs-screenshots and
# CI workflows run it on windows-latest.
set -euo pipefail
cd "$(dirname "$0")/.."

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) ;;
  *) echo "docs-screenshots: needs Windows (Git Bash); run the docs-screenshots workflow instead" >&2; exit 2 ;;
esac
if [[ "${DOCS_TOUR_INSTALL:-}" != 1 ]]; then
  echo "docs-screenshots: the tour installs and uninstalls Notepad4 on this machine; set DOCS_TOUR_INSTALL=1 to confirm" >&2
  exit 2
fi

out=${1:-docs/screenshots}
mkdir -p "$out"
work=$(mktemp -d)
trap 'rm -rf "$work" || true' EXIT  # a failed tour can leave the installer running

installer=$(cygpath -w "$work/notepad4-install.exe")
nsi=(Notepad4_en_x64_*.nsi)
makensis -WX -V2 "${nsi[0]}" "-XOutFile \"$installer\""
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/docs-tour.ps1 \
  -Installer "$installer" -OutDir "$(cygpath -w "$(cd "$out" && pwd)")"
