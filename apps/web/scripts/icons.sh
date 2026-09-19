#!/bin/sh
# Rebuilds the PWA icons from icons-src/*.svg, which are the phone's
# launcher icon (apps/mobile/assets/icon) on the brand gradient. The
# PNGs are committed, so a build never needs a rasterizer; run this only
# when the icon changes. Needs rsvg-convert (librsvg).
set -e
cd "$(dirname "$0")/.."
for size in 192 512; do
  rsvg-convert -w "$size" -h "$size" icons-src/icon-rounded.svg -o "public/icons/icon-$size.png"
  rsvg-convert -w "$size" -h "$size" icons-src/icon-maskable.svg -o "public/icons/maskable-$size.png"
done
rsvg-convert -w 180 -h 180 icons-src/icon-square.svg -o public/icons/apple-touch-icon.png
cp icons-src/icon-rounded.svg public/favicon.svg
