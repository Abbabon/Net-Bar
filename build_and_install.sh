#!/bin/bash
set -e

APP_NAME="Net Bar"
BUNDLE_NAME="Net Bar.app"
DEST_DIR="/Applications"

echo "=== Building Net Bar ==="
swift build -c release

BIN_PATH=$(swift build -c release --show-bin-path)

echo "=== Creating App Bundle ==="
rm -rf "$BUNDLE_NAME"
mkdir -p "$BUNDLE_NAME/Contents/MacOS"
mkdir -p "$BUNDLE_NAME/Contents/Resources"

cp "$BIN_PATH/NetBar" "$BUNDLE_NAME/Contents/MacOS/NetBar"
chmod +x "$BUNDLE_NAME/Contents/MacOS/NetBar"
cp Sources/NetSpeedMonitor/Info.plist "$BUNDLE_NAME/Contents/Info.plist"

if [ -f "Sources/NetSpeedMonitor/Resources/AppIcon.icns" ]; then
    cp "Sources/NetSpeedMonitor/Resources/AppIcon.icns" "$BUNDLE_NAME/Contents/Resources/AppIcon.icns"
fi
cp -r Sources/NetSpeedMonitor/Assets.xcassets "$BUNDLE_NAME/Contents/Resources/"

# Copy any resource bundles from build output
shopt -s nullglob
for bundle in "$BIN_PATH"/*.bundle; do
    cp -r "$bundle" "$BUNDLE_NAME/Contents/Resources/"
done
shopt -u nullglob

echo "=== Installing to $DEST_DIR ==="
rm -rf "$DEST_DIR/$BUNDLE_NAME"
mv "$BUNDLE_NAME" "$DEST_DIR/"

echo "=== Clearing Gatekeeper quarantine ==="
xattr -rd com.apple.quarantine "$DEST_DIR/$BUNDLE_NAME" 2>/dev/null || true

echo "=== Done ==="
echo "Net Bar has been installed to $DEST_DIR/$BUNDLE_NAME"
echo "Launch it from your Applications folder."
