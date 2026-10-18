#!/usr/bin/env bash
# Builds a universal (Apple Silicon + Intel) Teleprompter.app, ad-hoc signs it,
# and packages dist/Teleprompter.dmg with a drag-to-Applications layout.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
VERSION="${VERSION#v}"
if [[ ! "$VERSION" =~ ^[0-9]+(\.[0-9]+)*$ ]]; then
  VERSION="$(tr -d '[:space:]' < VERSION)"
fi
BUILD_NUMBER="${GITHUB_RUN_NUMBER:-1}"
echo "Building Teleprompter $VERSION ($BUILD_NUMBER)"

swift build -c release --arch arm64 --arch x86_64
BIN_DIR="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)"

rm -rf dist
APP="dist/Teleprompter.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Teleprompter" "$APP/Contents/MacOS/Teleprompter"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD_NUMBER/" Resources/Info.plist > "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
plutil -lint "$APP/Contents/Info.plist"

echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Teleprompter")"
lipo -archs "$APP/Contents/MacOS/Teleprompter" | grep -q arm64
lipo -archs "$APP/Contents/MacOS/Teleprompter" | grep -q x86_64

# Ad-hoc signature (no Apple Developer account needed).
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

STAGE="dist/dmg"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cat > "$STAGE/How to open.txt" <<'TXT'
How to install Teleprompter

1. Drag Teleprompter onto the Applications folder.
2. Open your Applications folder, RIGHT-click (or Control-click) Teleprompter and choose Open.
3. Click Open again in the warning box. You only need to do this the first time.

If macOS still won't open it: open System Settings > Privacy & Security,
scroll down and click "Open Anyway" next to Teleprompter.

Teleprompter lives in the menu bar at the top of the screen (the icon with lines of text).
TXT

hdiutil create -volname "Teleprompter" -srcfolder "$STAGE" -ov -format UDZO "dist/Teleprompter.dmg"
hdiutil verify "dist/Teleprompter.dmg"
rm -rf "$STAGE"
ls -lh dist
