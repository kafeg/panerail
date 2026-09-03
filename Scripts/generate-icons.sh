#!/usr/bin/env bash
# Rasterises Assets/icon.svg into Assets/AppIcon.icns.
#
# The .icns is committed so that building the app needs nothing but Xcode;
# re-run this only after editing the SVG. Requires librsvg (brew install librsvg).
set -euo pipefail

cd "$(dirname "$0")/.."

SVG="Assets/icon.svg"
ICONSET="Assets/AppIcon.iconset"
ICNS="Assets/AppIcon.icns"

command -v rsvg-convert >/dev/null || {
    echo "rsvg-convert not found. Install it with: brew install librsvg" >&2
    exit 1
}

rm -rf "$ICONSET"
mkdir -p "$ICONSET"

render() {
    rsvg-convert -w "$1" -h "$1" "$SVG" -o "$ICONSET/$2"
}

render 16   icon_16x16.png
render 32   icon_16x16@2x.png
render 32   icon_32x32.png
render 64   icon_32x32@2x.png
render 128  icon_128x128.png
render 256  icon_128x128@2x.png
render 256  icon_256x256.png
render 512  icon_256x256@2x.png
render 512  icon_512x512.png
render 1024 icon_512x512@2x.png

iconutil -c icns "$ICONSET" -o "$ICNS"
rm -rf "$ICONSET"

echo "Wrote $ICNS"
