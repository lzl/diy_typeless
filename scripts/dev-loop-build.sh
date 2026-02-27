#!/bin/bash
# Build/install/launch loop for fast DIYTypeless local debugging.
#
# Usage: ./scripts/dev-loop-build.sh [options]
#
# Options:
#   --xcode-root <path>          Xcode project root containing DIYTypeless.xcodeproj.
#                                Default: app/DIYTypeless
#   --configuration <name>       Xcode build configuration.
#                                Default: Debug
#   --derived-data <path>        Xcode derived data path.
#                                Default: .context/DerivedData
#   --destination-dir <path>     Install directory for copied app bundle.
#                                Default: ~/Applications
#   --app-name <name>            Installed app bundle name.
#                                Default: DIYTypeless Dev.app
#   --rust-profile <profile>     Rust profile for diy_typeless_core (debug|release).
#                                Default: inferred from --configuration
#                                (Debug->debug, Release->release)
#   --skip-rust-build            Skip cargo build step.
#   --testing                    Build only; skip app launch.
#   -h, --help                   Show this help message.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

XCODE_ROOT="$PROJECT_ROOT/app/DIYTypeless"
SCHEME="DIYTypeless"
CONFIGURATION="Debug"
DERIVED_DATA_PATH="$PROJECT_ROOT/.context/DerivedData"
DESTINATION_DIR="$HOME/Applications"
APP_NAME="DIYTypeless Dev.app"
RUST_PROFILE=""

SKIP_RUST_BUILD=0
TESTING=0

usage() {
    head -n 22 "$0" | tail -n 20
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --xcode-root)
            [[ $# -ge 2 ]] || { echo "Error: --xcode-root requires a value." >&2; exit 1; }
            XCODE_ROOT="$2"
            shift 2
            ;;
        --configuration)
            [[ $# -ge 2 ]] || { echo "Error: --configuration requires a value." >&2; exit 1; }
            CONFIGURATION="$2"
            shift 2
            ;;
        --derived-data)
            [[ $# -ge 2 ]] || { echo "Error: --derived-data requires a value." >&2; exit 1; }
            DERIVED_DATA_PATH="$2"
            shift 2
            ;;
        --destination-dir)
            [[ $# -ge 2 ]] || { echo "Error: --destination-dir requires a value." >&2; exit 1; }
            DESTINATION_DIR="$2"
            shift 2
            ;;
        --app-name)
            [[ $# -ge 2 ]] || { echo "Error: --app-name requires a value." >&2; exit 1; }
            APP_NAME="$2"
            shift 2
            ;;
        --rust-profile)
            [[ $# -ge 2 ]] || { echo "Error: --rust-profile requires a value." >&2; exit 1; }
            RUST_PROFILE="$2"
            shift 2
            ;;
        --skip-rust-build)
            SKIP_RUST_BUILD=1
            shift
            ;;
        --testing)
            TESTING=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Error: unknown option '$1'." >&2
            usage >&2
            exit 1
            ;;
    esac
done

if [[ -z "$RUST_PROFILE" ]]; then
    config_lc="$(printf '%s' "$CONFIGURATION" | tr '[:upper:]' '[:lower:]')"
    case "$config_lc" in
        debug)
            RUST_PROFILE="debug"
            ;;
        release)
            RUST_PROFILE="release"
            ;;
        *)
            echo "Error: --configuration '$CONFIGURATION' requires explicit --rust-profile (debug|release)." >&2
            exit 1
            ;;
    esac
fi

if [[ "$RUST_PROFILE" != "debug" && "$RUST_PROFILE" != "release" ]]; then
    echo "Error: --rust-profile must be 'debug' or 'release'." >&2
    exit 1
fi

XCODE_ROOT="$(cd "$XCODE_ROOT" && pwd)"
XCODE_PROJECT_PATH="$XCODE_ROOT/DIYTypeless.xcodeproj"
DERIVED_DATA_PATH="$(mkdir -p "$DERIVED_DATA_PATH" && cd "$DERIVED_DATA_PATH" && pwd)"
DESTINATION_DIR="$(mkdir -p "$DESTINATION_DIR" && cd "$DESTINATION_DIR" && pwd)"

if [[ ! -d "$XCODE_PROJECT_PATH" ]]; then
    echo "Error: Xcode project not found at $XCODE_PROJECT_PATH" >&2
    exit 1
fi

RUST_LIB_PATH="$PROJECT_ROOT/target/$RUST_PROFILE/libdiy_typeless_core.dylib"

if [[ "$SKIP_RUST_BUILD" -eq 0 ]]; then
    echo "=== [1/3] Building Rust core ($RUST_PROFILE) ==="
    if [[ "$RUST_PROFILE" == "release" ]]; then
        cargo build -p diy_typeless_core --release
    else
        cargo build -p diy_typeless_core
    fi
else
    echo "=== [1/3] Skipping Rust build ==="
    if [[ ! -f "$RUST_LIB_PATH" ]]; then
        echo "Error: expected Rust dylib not found at $RUST_LIB_PATH" >&2
        echo "Run without --skip-rust-build or choose a matching --rust-profile." >&2
        exit 1
    fi
fi

echo "=== [2/3] Building macOS app ($CONFIGURATION) ==="
(
    cd "$XCODE_ROOT"
    xcodebuild \
        -project "$XCODE_PROJECT_PATH" \
        -scheme "$SCHEME" \
        -configuration "$CONFIGURATION" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        build
)

BUILT_APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/DIYTypeless.app"
if [[ ! -d "$BUILT_APP_PATH" ]]; then
    echo "Error: built app not found at $BUILT_APP_PATH" >&2
    exit 1
fi

TARGET_APP_PATH="$DESTINATION_DIR/$APP_NAME"

echo "=== [3/3] Installing app to $TARGET_APP_PATH ==="
if pgrep -x DIYTypeless >/dev/null 2>&1; then
    echo "- Stopping running DIYTypeless process"
    pkill -x DIYTypeless || true
    sleep 1
fi

rm -rf "$TARGET_APP_PATH"
cp -R "$BUILT_APP_PATH" "$TARGET_APP_PATH"

if [[ "$TESTING" -eq 0 ]]; then
    echo "Launching: $TARGET_APP_PATH"
    open -n "$TARGET_APP_PATH"
else
    echo "Launch skipped (testing mode)."
fi

echo
echo "Done."
echo "- Installed app: $TARGET_APP_PATH"
echo "- DerivedData:    $DERIVED_DATA_PATH"
