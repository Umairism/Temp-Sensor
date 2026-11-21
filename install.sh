#!/usr/bin/env bash
#
# Thermal Monitor Pro — installer for KDE Plasma 6
#
# Usage:
#   ./install.sh              install or upgrade the plasmoid for the current user
#   ./install.sh --uninstall  remove the plasmoid
#   ./install.sh --help       show this help
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

PLUGIN_ID="com.github.umairism.thermalmonitor"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="${REPO_ROOT}/package"

info()  { printf '%s\n' "$*"; }
warn()  { printf 'Warning: %s\n' "$*" >&2; }
die()   { printf 'Error: %s\n' "$*" >&2; exit 1; }

usage() {
    sed -n '3,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

find_kpackagetool() {
    if command -v kpackagetool6 >/dev/null 2>&1; then
        echo "kpackagetool6"
    elif command -v plasmapkg2 >/dev/null 2>&1; then
        echo "plasmapkg2"
    else
        return 1
    fi
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

KPACKAGE="$(find_kpackagetool)" || die "kpackagetool6 not found. Install KDE Plasma 6 first (e.g. 'dnf install kf6-kpackage' / 'apt install plasma-workspace')."

if [[ "${1:-}" == "--uninstall" ]]; then
    info "Removing ${PLUGIN_ID}…"
    "$KPACKAGE" --type Plasma/Applet --remove "$PLUGIN_ID"
    info "Done. Restart plasmashell (e.g. 'kquitapp6 plasmashell && kstart plasmashell') to finish removal."
    exit 0
fi

[[ -f "${PACKAGE_DIR}/metadata.json" ]] || die "Package directory ${PACKAGE_DIR} looks wrong (missing metadata.json). Run this script from the repository root."

if ! command -v sensors >/dev/null 2>&1; then
    warn "'lm_sensors' is not installed; the widget will have no data until sensors exist."
    warn "Install lm_sensors for your distribution and run sensors-detect, for example:"
    warn "  Fedora:        sudo dnf install lm_sensors && sudo sensors-detect --auto"
    warn "  Debian/Ubuntu: sudo apt install lm-sensors && sudo sensors-detect --auto"
    warn "  Arch:          sudo pacman -S lm_sensors && sudo sensors-detect --auto"
    warn "  openSUSE:      sudo zypper install sensors && sudo sensors-detect --auto"
fi

if "$KPACKAGE" --type Plasma/Applet --show "$PLUGIN_ID" >/dev/null 2>&1; then
    info "Upgrading existing installation…"
    "$KPACKAGE" --type Plasma/Applet --upgrade "$PACKAGE_DIR"
else
    info "Installing ${PLUGIN_ID}…"
    "$KPACKAGE" --type Plasma/Applet --install "$PACKAGE_DIR"
fi

cat <<EOF

Done! Add the widget to your desktop or panel:
  1. Right-click your desktop or an empty panel area → Add Widgets…
  2. Search for "Thermal Monitor Pro"
  3. Drag it onto the desktop or panel

Test it standalone in a window first (recommended):
  plasmawindowed ${PLUGIN_ID}

If the widget does not appear or shows no sensors, restart Plasma:
  kquitapp6 plasmashell && kstart plasmashell
EOF
