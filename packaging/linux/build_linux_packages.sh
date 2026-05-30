#!/usr/bin/env bash
# Build AppImage + .deb from a release Flutter Linux bundle.
# Run from repo root (or via `melos`/CI). Output -> dist/.
set -euo pipefail
cd "$(dirname "$0")/../.."

APP=peerbeat
VERSION="${PEERBEAT_VERSION:-0.1.0}"
ARCH=amd64
BUNDLE="apps/peerbeat/build/linux/x64/release/bundle"
DIST="dist"
ICON_SRC="assets/icon/PeerBeat.png"

[ -d "$BUNDLE" ] || { echo "Missing $BUNDLE — run 'flutter build linux --release' first." >&2; exit 1; }
mkdir -p "$DIST"
bash scripts/gen_icons.sh

# ── .deb ────────────────────────────────────────────────────────────────────
echo "==> Building .deb"
ROOT="$DIST/deb/$APP"
rm -rf "$ROOT"
mkdir -p "$ROOT/DEBIAN" "$ROOT/opt/$APP" "$ROOT/usr/bin" \
         "$ROOT/usr/share/applications" "$ROOT/usr/share/metainfo"
cp -r "$BUNDLE/." "$ROOT/opt/$APP/"
ln -sf "/opt/$APP/$APP" "$ROOT/usr/bin/$APP"
cp packaging/linux/peerbeat.desktop "$ROOT/usr/share/applications/"
cp packaging/linux/io.github.ramazanberk20.PeerBeat.metainfo.xml "$ROOT/usr/share/metainfo/"
for s in 16 22 24 32 48 64 128 256 512; do
  d="$ROOT/usr/share/icons/hicolor/${s}x${s}/apps"; mkdir -p "$d"
  cp "assets/icon/generated/hicolor/${s}x${s}/apps/peerbeat.png" "$d/peerbeat.png"
done
cat > "$ROOT/DEBIAN/control" <<EOF
Package: $APP
Version: $VERSION
Section: sound
Priority: optional
Architecture: $ARCH
Depends: libgtk-3-0, libasound2
Maintainer: RamazanBerk20 <ramazanberksirin@protonmail.com>
Description: Local-first music player with LAN peer-to-peer sharing
 PeerBeat plays your local music and shares playlists with peers on your LAN —
 encrypted, no cloud, no accounts.
EOF
dpkg-deb --build --root-owner-group "$ROOT" "$DIST/${APP}_${VERSION}_${ARCH}.deb"

# ── AppImage ──────────────────────────────────────────────────────────────────
echo "==> Building AppImage"
if ! command -v linuxdeploy >/dev/null 2>&1; then
  curl -fsSL -o "$DIST/linuxdeploy" \
    https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
  chmod +x "$DIST/linuxdeploy"
  LINUXDEPLOY="$DIST/linuxdeploy"
else
  LINUXDEPLOY="$(command -v linuxdeploy)"
fi
APPDIR="$DIST/AppDir"; rm -rf "$APPDIR"; mkdir -p "$APPDIR/usr/bin"
cp -r "$BUNDLE/." "$APPDIR/usr/bin/"
"$LINUXDEPLOY" --appdir "$APPDIR" \
  --executable "$APPDIR/usr/bin/$APP" \
  --desktop-file packaging/linux/peerbeat.desktop \
  --icon-file "$ICON_SRC" --icon-filename peerbeat \
  --output appimage
mv ./*.AppImage "$DIST/PeerBeat-${VERSION}-x86_64.AppImage" 2>/dev/null || true

# ── Plain tarball (consumed by the peerbeat-bin AUR package) ─────────────────
echo "==> Building tarball"
TARDIR="$DIST/tar/$APP"; rm -rf "$TARDIR"; mkdir -p "$TARDIR"
cp -r "$BUNDLE/." "$TARDIR/"
tar -C "$DIST/tar" -czf "$DIST/PeerBeat-${VERSION}-linux-x86_64.tar.gz" "$APP"

echo "==> Done. Artifacts in $DIST/:"
ls -1 "$DIST"/*.deb "$DIST"/*.AppImage "$DIST"/*.tar.gz 2>/dev/null || true
