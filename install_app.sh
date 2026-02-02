#!/bin/bash
set -e

# Configuration
APP_NAME="NetBar"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
DEST_DIR="/Applications"

echo "Starting Installation for $APP_NAME..."

# 1. Clean previous bundle locally
if [ -d "$APP_BUNDLE" ]; then
    echo "Removing existing local bundle..."
    rm -rf "$APP_BUNDLE"
fi

# 2. Create Directory Structure
echo "Creating Bundle Structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 3. Copy Binary
echo "Copying Binary..."
if [ ! -f "$BUILD_DIR/${APP_NAME}" ]; then
    echo "Error: Binary not found at $BUILD_DIR/${APP_NAME}. Did you build it?"
    exit 1
fi
cp "$BUILD_DIR/${APP_NAME}" "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"
chmod +x "$APP_BUNDLE/Contents/MacOS/${APP_NAME}"

# 4. Copy Info.plist
echo "Copying Info.plist..."
cp "Sources/NetSpeedMonitor/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# 5. Compile Assets (Important for AppIcon)
echo "Compiling Assets..."
/usr/bin/actool "Sources/NetSpeedMonitor/Assets.xcassets" \
    --compile "$APP_BUNDLE/Contents/Resources" \
    --platform macosx \
    --minimum-deployment-target 14.0 \
    --app-icon AppIcon \
    --output-partial-info-plist "/tmp/${APP_NAME}_assetcatalog_generated_info.plist"

# 5a. Explicitly copy AppIcon.icns (fallback if actool doesn't generate it)
echo "Copying AppIcon.icns..."
if [ -f "Sources/NetSpeedMonitor/Resources/AppIcon.icns" ]; then
    cp "Sources/NetSpeedMonitor/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
else
    echo "Warning: AppIcon.icns not found in Resources folder"
fi

# 6. Copy Resource Bundles (Dependencies and Main module resources)
echo "Copying Resource Bundles..."
# Use glob expansion, handled by shell. Enable nullglob to avoid errors if no bundles match.
shopt -s nullglob
for bundle in "$BUILD_DIR"/*.bundle; do
    echo "Copying $bundle..."
    cp -r "$bundle" "$APP_BUNDLE/Contents/Resources/"
done
shopt -u nullglob

# 7. Sign the Application
echo "Signing Application..."
if [ -f "Sources/NetSpeedMonitor/NetSpeedMonitor.entitlements" ]; then
    codesign -s - --entitlements "Sources/NetSpeedMonitor/NetSpeedMonitor.entitlements" --force --deep "$APP_BUNDLE"
else
    # Fallback to simple signing
    codesign -s - --force --deep "$APP_BUNDLE"
fi

# 8. Install
echo "Installing to $DEST_DIR..."
if [ -d "$DEST_DIR/$APP_BUNDLE" ]; then
    echo "Removing existing app in $DEST_DIR..."
    rm -rf "$DEST_DIR/$APP_BUNDLE"
fi

mv "$APP_BUNDLE" "$DEST_DIR/"

# 9. Force macOS to refresh icon cache
echo "Refreshing macOS icon cache..."
touch "$DEST_DIR/$APP_BUNDLE"

# Register with Launch Services to update Spotlight and app database
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$DEST_DIR/$APP_BUNDLE"

# Restart Dock to refresh app icons
echo "Restarting Dock to refresh icons..."
killall Dock

echo "Installation Complete! NetBar has been installed to $DEST_DIR"
echo "The Dock has been restarted to refresh the app icon."
