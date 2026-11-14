#!/usr/bin/env bash
set -euo pipefail

WIDGET_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ID="com.custom.thermalmonitor"

echo "=== Thermal Monitor Pro - Fedora KDE Plasma 6 Installer ==="

if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "Error: kpackagetool6 not found. Are you running KDE Plasma 6?"
    exit 1
fi

if ! command -v sensors >/dev/null 2>&1; then
    echo "Warning: 'lm_sensors' is not installed. Installing it is strongly recommended:"
    echo "  sudo dnf install lm_sensors && sudo sensors-detect --auto"
fi

if kpackagetool6 -t Plasma/Applet -s "$PLUGIN_ID" >/dev/null 2>&1; then
    echo "Updating existing installation..."
    kpackagetool6 -t Plasma/Applet -u "$WIDGET_DIR"
else
    echo "Installing widget..."
    kpackagetool6 -t Plasma/Applet -i "$WIDGET_DIR"
fi

echo ""
echo "Done! To add it to your desktop:"
echo "  1. Right-click your desktop -> Add Widgets..."
echo "  2. Search for 'Thermal Monitor Pro'"
echo "  3. Drag it onto your desktop or panel."
echo ""
echo "To test it standalone in a window:"
echo "  plasmawindowed $PLUGIN_ID"
