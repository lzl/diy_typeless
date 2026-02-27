#!/bin/bash
# Build universal binary for Rust core library
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== Building Rust Universal Binary ==="
echo ""

# Step 1: Build for arm64
echo "[1/4] Building for arm64..."
cd "$PROJECT_ROOT"
cargo build -p diy_typeless_core --release --target aarch64-apple-darwin
echo "      arm64 build complete"
echo ""

# Step 2: Build for x86_64
echo "[2/4] Building for x86_64..."
cargo build -p diy_typeless_core --release --target x86_64-apple-darwin
echo "      x86_64 build complete"
echo ""

# Step 3: Create universal binary
echo "[3/4] Creating universal binary..."
mkdir -p "$PROJECT_ROOT/target/release"

lipo -create \
    "$PROJECT_ROOT/target/aarch64-apple-darwin/release/libdiy_typeless_core.a" \
    "$PROJECT_ROOT/target/x86_64-apple-darwin/release/libdiy_typeless_core.a" \
    -output "$PROJECT_ROOT/target/release/libdiy_typeless_core.a"

lipo -create \
    "$PROJECT_ROOT/target/aarch64-apple-darwin/release/libdiy_typeless_core.dylib" \
    "$PROJECT_ROOT/target/x86_64-apple-darwin/release/libdiy_typeless_core.dylib" \
    -output "$PROJECT_ROOT/target/release/libdiy_typeless_core.dylib"

echo "      Universal binary created"
echo ""

# Step 4: Verify
echo "[4/4] Verifying universal binary..."
lipo -info "$PROJECT_ROOT/target/release/libdiy_typeless_core.a"
lipo -info "$PROJECT_ROOT/target/release/libdiy_typeless_core.dylib"
echo ""

echo "=== Build Complete ==="
