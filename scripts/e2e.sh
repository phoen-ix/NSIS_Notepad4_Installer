#!/usr/bin/env bash
# E2E suite (map: e2e/COVERAGE.md). Compiles the installer and a fixture build whose online fetch
# asks http://127.0.0.1:$PORT_BASE/latest.json instead of the GitHub API. On Windows (Git Bash,
# makensis, Windows PowerShell and Python on PATH) it then runs the screenshot tour as the page
# sweep (PNGs in $ARTIFACTS/screenshots) and every e2e/test-*.ps1. Those really install Notepad4,
# replace Windows Notepad for a while and uninstall again, so they refuse to run without
# E2E_INSTALL=1: throwaway machines only (ci.yml's e2e job). Elsewhere it stops after compiling.
set -euo pipefail
cd "$(dirname "$0")/.."

port=${PORT_BASE:-8765}
artifacts=${ARTIFACTS:-$(mktemp -d)}
mkdir -p "$artifacts"
exec > >(tee "$artifacts/e2e.log") 2>&1
work=$(mktemp -d)
trap 'rm -rf "$work" || true' EXIT

winpath() { if command -v cygpath >/dev/null; then cygpath -w "$1"; else printf '%s\n' "$1"; fi; }
build() { makensis -WX -V2 "$(winpath "$1")" "-XOutFile \"$(winpath "$2")\""; }

nsi=(Notepad4_en_x64_*.nsi)
build "${nsi[0]}" "$work/notepad4-install.exe"
mkdir "$work/fixture"
cp -r "${nsi[0]}" psexec.nsh Notepad4_Installer.ico check_update.ps1 download_update.ps1 Notepad4_en_x64_*/ "$work/fixture/"
api=https://api.github.com/repos/zufuliu/notepad4/releases/latest
grep -qF "$api" check_update.ps1 || { echo "e2e: check_update.ps1 no longer asks $api; update the fixture build" >&2; exit 1; }
sed -i "s|$api|http://127.0.0.1:$port/latest.json|" "$work/fixture/check_update.ps1"
build "$work/fixture/${nsi[0]}" "$work/notepad4-fixture.exe"

case "$(uname -s)" in
  MINGW* | MSYS* | CYGWIN*) ;;
  *) echo "e2e: both installers compile; the install tests need Windows (ci.yml e2e job)"; exit 0 ;;
esac
if [[ "${E2E_INSTALL:-}" != 1 ]]; then
  echo "e2e: the tests install Notepad4 and replace Windows Notepad on this machine; set E2E_INSTALL=1 to confirm" >&2
  exit 2
fi

psh() { powershell -NoProfile -ExecutionPolicy Bypass -File "$@"; }
installer=$(winpath "$work/notepad4-install.exe")
mkdir -p "$artifacts/screenshots"
psh scripts/docs-tour.ps1 -Installer "$installer" -OutDir "$(winpath "$(cd "$artifacts/screenshots" && pwd)")"
psh e2e/test-install.ps1 -Installer "$installer"
psh e2e/test-silent.ps1 -Installer "$installer"
psh e2e/test-update.ps1 -Installer "$(winpath "$work/notepad4-fixture.exe")" -Port "$port"
psh e2e/test-download.ps1
psh e2e/test-wizard.ps1 -Installer "$installer"
echo "e2e: all passed"
