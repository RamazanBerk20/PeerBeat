#!/usr/bin/env bash
# Generate platform icons from the single source assets/icon/PeerBeat.png.
#
# flutter_launcher_icons handles the *launcher* icons (Android adaptive/maskable,
# Windows .ico embedded in the runner, etc.) — run `dart run flutter_launcher_icons`
# in apps/peerbeat. THIS script generates the extras that tool doesn't:
#   - Linux hicolor PNGs for the .desktop entry / app menu
#   - tray icons (small) for tray_manager
#   - a multi-resolution Windows .ico for the installer / window icon
# Requires ImageMagick 7 (`magick`).
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="assets/icon/PeerBeat.png"
OUT="assets/icon/generated"
command -v magick >/dev/null || { echo "ImageMagick (magick) required" >&2; exit 1; }
[ -f "$SRC" ] || { echo "missing $SRC" >&2; exit 1; }

echo "==> hicolor PNGs"
for s in 16 22 24 32 48 64 128 256 512; do
  mkdir -p "$OUT/hicolor/${s}x${s}/apps"
  magick "$SRC" -resize ${s}x${s} "$OUT/hicolor/${s}x${s}/apps/peerbeat.png"
done

echo "==> tray icons"
mkdir -p "$OUT/tray"
for s in 16 22 24 32 44 64; do
  magick "$SRC" -resize ${s}x${s} "$OUT/tray/tray-${s}.png"
done

echo "==> Windows .ico (multi-size)"
mkdir -p "$OUT/windows"
magick "$SRC" -define icon:auto-resize=16,24,32,48,64,128,256 "$OUT/windows/peerbeat.ico"

echo "Done -> $OUT"
