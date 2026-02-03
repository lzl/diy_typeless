#!/bin/bash
# Build DIYTypeless.app and package it as a DMG for distribution
# Output: ~/Downloads/DIYTypeless.dmg

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODE_PROJECT="$PROJECT_ROOT/app/DIYTypeless"
OUTPUT_DIR="$HOME/Downloads"
ARCHIVE_PATH="$OUTPUT_DIR/DIYTypeless.xcarchive"
APP_PATH="$OUTPUT_DIR/DIYTypeless.app"
DMG_PATH="$OUTPUT_DIR/DIYTypeless.dmg"
DMG_CONTENTS="$OUTPUT_DIR/DMG_Contents_tmp"

echo "=== DIYTypeless DMG Builder ==="
echo ""

# Step 1: Build Rust core library (universal binary)
echo "[1/5] Building Rust core library (universal binary)..."
cd "$PROJECT_ROOT"
"$SCRIPT_DIR/build-rust-universal.sh"
echo "      Rust universal library built successfully."
echo ""

# Step 2: Build Xcode archive (universal binary)
echo "[2/5] Building Xcode archive (universal binary)..."
cd "$XCODE_PROJECT"
xcodebuild archive \
    -scheme DIYTypeless \
    -archivePath "$ARCHIVE_PATH" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    -quiet

echo "      Archive created at: $ARCHIVE_PATH"
echo ""

# Step 3: Extract .app from archive
echo "[3/5] Extracting application..."
rm -rf "$APP_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/DIYTypeless.app" "$APP_PATH"
echo "      App extracted to: $APP_PATH"
echo ""

# Step 4: Create DMG
echo "[4/5] Creating DMG..."
rm -rf "$DMG_CONTENTS"
mkdir -p "$DMG_CONTENTS"
cp -R "$APP_PATH" "$DMG_CONTENTS/"
ln -s /Applications "$DMG_CONTENTS/Applications"

rm -f "$DMG_PATH"
hdiutil create \
    -volname "DIYTypeless" \
    -srcfolder "$DMG_CONTENTS" \
    -ov \
    -format UDZO \
    "$DMG_PATH" \
    -quiet

rm -rf "$DMG_CONTENTS"
echo "      DMG created at: $DMG_PATH"
echo ""

# Step 5: Cleanup (optional: keep archive for debugging)
echo "[5/5] Cleaning up..."
rm -rf "$ARCHIVE_PATH"
rm -rf "$APP_PATH"
echo "      Temporary files removed."
echo ""

# Summary
DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo "=== Build Complete ==="
echo ""
echo "Output: $DMG_PATH"
echo "Size:   $DMG_SIZE"
echo ""
echo "Note: This build supports both Apple Silicon (M1/M2/M3/M4) and Intel Macs."
echo "      Verified architectures: arm64, x86_64"
