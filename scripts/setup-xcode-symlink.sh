#!/bin/bash
# Setup script to link Xcode project to source files in diy_typeless/app

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
XCODE_PROJECT_ROOT="/Users/lzl/Documents/GitHub/diy_typeless_mac"

SOURCE_DIR="$PROJECT_ROOT/app/DIYTypeless/DIYTypeless"
TARGET_DIR="$XCODE_PROJECT_ROOT/DIYTypeless/DIYTypeless"

echo "=== DIYTypeless Xcode Project Symlink Setup ==="
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo ""

# Verify source exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "Error: Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Verify Xcode project root exists
if [ ! -d "$XCODE_PROJECT_ROOT" ]; then
    echo "Error: Xcode project root does not exist: $XCODE_PROJECT_ROOT"
    exit 1
fi

# Backup and remove existing target
if [ -d "$TARGET_DIR" ] && [ ! -L "$TARGET_DIR" ]; then
    echo "Backing up existing DIYTypeless folder..."
    BACKUP_DIR="${TARGET_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    mv "$TARGET_DIR" "$BACKUP_DIR"
    echo "Backup created: $BACKUP_DIR"
elif [ -L "$TARGET_DIR" ]; then
    echo "Removing existing symlink..."
    rm "$TARGET_DIR"
fi

# Create symlink
echo "Creating symlink..."
ln -s "$SOURCE_DIR" "$TARGET_DIR"
echo "Symlink created: $TARGET_DIR -> $SOURCE_DIR"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Now you can edit Swift files in either location:"
echo "  - $SOURCE_DIR"
echo "  - $TARGET_DIR (symlinked)"
echo ""
echo "Changes will be automatically reflected in both the Xcode project"
echo "and the diy_typeless repository."
