#!/bin/bash
set -e

APP_NAME="NotchPrompter"
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
ENTITLEMENTS="$APP_NAME/Resources/NotchPrompter.entitlements"

echo "Building $APP_NAME..."
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp "$BUILD_DIR/$APP_NAME" "$MACOS/$APP_NAME"

# Copy Info.plist
cp "$APP_NAME/Resources/Info.plist" "$CONTENTS/Info.plist"

# Copy app icon
if [ -f "$APP_NAME/Resources/AppIcon.icns" ]; then
    cp "$APP_NAME/Resources/AppIcon.icns" "$RESOURCES/AppIcon.icns"
fi

# Sign with entitlements (entitlements file stays outside the bundle)
codesign --force --sign - --entitlements "$ENTITLEMENTS" "$MACOS/$APP_NAME"

echo ""
echo "Built $APP_BUNDLE successfully."
echo "To run:  open $APP_BUNDLE"
echo "To install:  cp -r $APP_BUNDLE /Applications/"
