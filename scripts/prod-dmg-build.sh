#!/bin/bash
# Build DIYTypeless.app and package it as a DMG for distribution
# Output: ~/Downloads/DIYTypeless.dmg

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODE_PROJECT="$PROJECT_ROOT/app/DIYTypeless"
OUTPUT_DIR="$HOME/Downloads"
ARCHIVE_PATH="$OUTPUT_DIR/DIYTypeless.xcarchive"
APP_PATH="$OUTPUT_DIR/DIYTypeless.app"
DMG_PATH="$OUTPUT_DIR/DIYTypeless.dmg"

echo "=== DIYTypeless DMG Builder ==="
echo ""

# Preflight: ensure create-dmg is available before expensive build steps.
if ! command -v create-dmg >/dev/null 2>&1; then
    echo "Error: 'create-dmg' is not installed or not in PATH." >&2
    echo "Install it and retry." >&2
    echo "  - Homebrew: brew install create-dmg" >&2
    echo "  - npm:      npm install --global create-dmg" >&2
    echo "Details: https://github.com/sindresorhus/create-dmg" >&2
    exit 1
fi

if ! CREATE_DMG_HELP="$(create-dmg --help 2>&1)"; then
    echo "Error: failed to execute 'create-dmg --help'." >&2
    echo "Please reinstall the official tool from:" >&2
    echo "  https://github.com/sindresorhus/create-dmg" >&2
    exit 1
fi

if [[ "$CREATE_DMG_HELP" != *"--no-version-in-filename"* ]]; then
    echo "Error: found an incompatible 'create-dmg' CLI in PATH." >&2
    echo "This script requires sindresorhus/create-dmg." >&2
    echo "Details: https://github.com/sindresorhus/create-dmg" >&2
    exit 1
fi

# Step 1: Build Rust core library (universal binary)
echo "[1/5] Building Rust core library (universal binary)..."
cd "$PROJECT_ROOT"
"$SCRIPT_DIR/prod-rust-build.sh"
echo "      Rust universal library built successfully."
echo ""

# Step 2: Build Xcode archive (universal binary)
echo "[2/5] Building Xcode archive (universal binary)..."
cd "$XCODE_PROJECT"
# Work around a Swift x86_64 Release optimizer crash in UniFFI-generated bindings.
xcodebuild archive \
    -scheme DIYTypeless \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE_PATH" \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO \
    OTHER_SWIFT_FLAGS='$(inherited) -Xfrontend -disable-sil-perf-optzns' \
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
create-dmg \
    --overwrite \
    --no-version-in-filename \
    --no-code-sign \
    "$APP_PATH" \
    "$OUTPUT_DIR"

if [[ ! -f "$DMG_PATH" ]]; then
    echo "Error: expected DMG was not created at $DMG_PATH" >&2
    exit 1
fi

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
