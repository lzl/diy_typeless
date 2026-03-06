#!/bin/bash
# Launch the already-installed DIYTypeless dev app without rebuilding it.
#
# Usage: ./scripts/open-dev-app.sh

set -euo pipefail

APP_NAME="DIYTypeless Dev.app"
DESTINATION_DIR="$HOME/Applications"
TARGET_APP_PATH="$DESTINATION_DIR/$APP_NAME"
TARGET_BINARY_PATH="$TARGET_APP_PATH/Contents/MacOS/DIYTypeless"

usage() {
    cat <<'EOF'
Usage: ./scripts/open-dev-app.sh

Launch the already-installed DIYTypeless dev app from ~/Applications.
This script does not build or install the app.
EOF
}

case "${1:-}" in
    -h|--help)
        usage
        exit 0
        ;;
    "")
        ;;
    *)
        echo "Error: unknown option '$1'." >&2
        usage >&2
        exit 1
        ;;
esac

if [[ ! -d "$TARGET_APP_PATH" ]]; then
    echo "Error: installed dev app not found at $TARGET_APP_PATH" >&2
    echo "Build and install it first with ./scripts/dev-loop-build.sh" >&2
    exit 1
fi

if [[ ! -x "$TARGET_BINARY_PATH" ]]; then
    echo "Error: app executable not found at $TARGET_BINARY_PATH" >&2
    exit 1
fi

echo "Launching: $TARGET_APP_PATH"
"$TARGET_BINARY_PATH" &
