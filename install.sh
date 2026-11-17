#!/usr/bin/env bash
# Installs Afterglow for the current user (no root needed): ~/.local/share/afterglow + a launcher.
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${XDG_DATA_HOME:-$HOME/.local/share}/afterglow"
BIN="$HOME/.local/bin"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/scalable/apps"

missing=()
python3 -c "import PySide6" 2>/dev/null || missing+=("PySide6")
python3 -c "import requests" 2>/dev/null || missing+=("requests")
command -v mpv >/dev/null || missing+=("mpv")
command -v yt-dlp >/dev/null || missing+=("yt-dlp")
[ -d /usr/lib/qt6/qml/org/kde/layershell ] || [ -d /usr/lib64/qt6/qml/org/kde/layershell ] || missing+=("layer-shell-qt")
if [ ${#missing[@]} -gt 0 ]; then
  echo "Missing: ${missing[*]}"
  echo "Arch / CachyOS:  sudo pacman -S --needed pyside6 python-requests python-dbus-fast mpv yt-dlp layer-shell-qt qt6-multimedia-ffmpeg"
  echo "Fedora:          sudo dnf install python3-pyside6 python3-requests python3-dbus-fast mpv yt-dlp layer-shell-qt qt6-qtmultimedia"
  exit 1
fi

rm -rf "$DEST"
mkdir -p "$DEST" "$BIN" "$APPS" "$ICONS"
cp -r "$SRC/afterglow" "$DEST/"
find "$DEST" -name __pycache__ -prune -exec rm -rf {} +
cat > "$BIN/afterglow" <<EOF
#!/bin/sh
export PYTHONPATH="$DEST\${PYTHONPATH:+:\$PYTHONPATH}"
exec python3 -m afterglow "\$@"
EOF
chmod +x "$BIN/afterglow"
cp "$SRC/packaging/afterglow.desktop" "$APPS/afterglow.desktop"
cp "$SRC/afterglow/assets/afterglow.svg" "$ICONS/afterglow.svg"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" >/dev/null 2>&1 || true
echo "Installed. Run: afterglow   (make sure ~/.local/bin is in PATH)"
