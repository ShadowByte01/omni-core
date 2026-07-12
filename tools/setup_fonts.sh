#!/usr/bin/env bash
# Re-downloads the hand-drawn fonts (Caveat, Patrick Hand, Inter) used by the
# "Let's Sketch" theme into assets/fonts/. Run from the project root.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)/assets/fonts"
mkdir -p "$DIR"

echo "Fetching fonts into $DIR ..."

curl -fsSL -o "$DIR/Caveat.ttf" \
  "https://github.com/google/fonts/raw/main/ofl/caveat/Caveat%5Bwght%5D.ttf"

curl -fsSL -o "$DIR/PatrickHand-Regular.ttf" \
  "https://github.com/google/fonts/raw/main/ofl/patrickhand/PatrickHand-Regular.ttf"

curl -fsSL -o "$DIR/Inter.ttf" \
  "https://github.com/google/fonts/raw/main/ofl/inter/Inter%5Bopsz%2Cwght%5D.ttf"

echo "Done. Fonts:"
ls -la "$DIR"
