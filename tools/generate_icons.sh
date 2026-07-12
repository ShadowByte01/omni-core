#!/usr/bin/env bash
# Generates the Android + iOS + desktop app icons from the OmniCore logo.
#
# Run AFTER `flutter pub get`:
#   bash tools/generate_icons.sh
#
# Or run the dart command directly:
#   dart run flutter_launcher_icons
#
# The logo is at assets/images/omni_logo.png (1254x1254, black bg + white art).
# The config lives in pubspec.yaml under `flutter_launcher_icons:`.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DIR"

echo "=== Generating OmniCore app icons from assets/images/omni_logo.png ==="
echo ""

# Verify the logo exists.
if [ ! -f "assets/images/omni_logo.png" ]; then
  echo "ERROR: assets/images/omni_logo.png not found!"
  echo "Place your logo at assets/images/omni_logo.png before running this."
  exit 1
fi

echo "Logo found: $(file assets/images/omni_logo.png | cut -d: -f2)"
echo ""

# Generate the icons.
dart run flutter_launcher_icons

echo ""
echo "=== Done! App icons generated in: ==="
echo "  android/app/src/main/res/mipmap-*/  (Android)"
echo "  ios/Runner/Assets.xcassets/AppIcon.appiconset/  (iOS)"
echo "  macos/Runner/Assets.xcassets/AppIcon.appiconset/  (macOS)"
echo "  windows/runner/resources/  (Windows)"
echo ""
echo "Now run: flutter build apk --release"
