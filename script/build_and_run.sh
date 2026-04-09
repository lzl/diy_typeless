#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEV_LOOP_SCRIPT="$ROOT_DIR/scripts/dev-loop-build.sh"
APP_NAME="DIYTypeless"
APP_BUNDLE_PATH="$HOME/Applications/DIYTypeless Dev.app"
APP_BINARY_PATH="$APP_BUNDLE_PATH/Contents/MacOS/$APP_NAME"
TELEMETRY_SUBSYSTEM="com.lizunlong.DIYTypeless.dev"

usage() {
    cat <<'EOF'
Usage: ./script/build_and_run.sh [run|--debug|--logs|--telemetry|--verify] [dev-loop args...]

Modes:
  run, --run           Build, install, and launch the app.
  --debug              Build and install without launching, then start under lldb.
  --logs               Build, install, launch, then stream unified logs for the app process.
  --telemetry          Build, install, launch, then stream unified logs for the app subsystem.
  --verify             Build, install, launch, then verify the process exists.

Any additional arguments are passed through to ./scripts/dev-loop-build.sh.
Examples:
  ./script/build_and_run.sh
  ./script/build_and_run.sh --verify
  ./script/build_and_run.sh --logs --configuration Release
EOF
}

ensure_dev_loop_script() {
    if [[ ! -x "$DEV_LOOP_SCRIPT" ]]; then
        echo "Error: expected executable script at $DEV_LOOP_SCRIPT" >&2
        exit 1
    fi
}

ensure_installed_binary() {
    if [[ ! -x "$APP_BINARY_PATH" ]]; then
        echo "Error: app executable not found at $APP_BINARY_PATH" >&2
        echo "Run ./scripts/dev-loop-build.sh first or use this script without --debug." >&2
        exit 1
    fi
}

MODE="run"
if [[ $# -gt 0 ]]; then
    case "$1" in
        run|--run)
            MODE="run"
            shift
            ;;
        debug|--debug)
            MODE="debug"
            shift
            ;;
        logs|--logs)
            MODE="logs"
            shift
            ;;
        telemetry|--telemetry)
            MODE="telemetry"
            shift
            ;;
        verify|--verify)
            MODE="verify"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
    esac
fi

BUILD_ARGS=("$@")

ensure_dev_loop_script

run_dev_loop() {
    if [[ ${#BUILD_ARGS[@]} -eq 0 ]]; then
        "$DEV_LOOP_SCRIPT"
    else
        "$DEV_LOOP_SCRIPT" "${BUILD_ARGS[@]}"
    fi
}

run_dev_loop_testing() {
    if [[ ${#BUILD_ARGS[@]} -eq 0 ]]; then
        "$DEV_LOOP_SCRIPT" --testing
    else
        "$DEV_LOOP_SCRIPT" --testing "${BUILD_ARGS[@]}"
    fi
}

case "$MODE" in
    run)
        run_dev_loop
        ;;
    debug)
        run_dev_loop_testing
        ensure_installed_binary
        exec lldb -- "$APP_BINARY_PATH"
        ;;
    logs)
        run_dev_loop
        exec /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
        ;;
    telemetry)
        run_dev_loop
        exec /usr/bin/log stream --info --style compact --predicate "subsystem == \"$TELEMETRY_SUBSYSTEM\""
        ;;
    verify)
        run_dev_loop
        sleep 1
        if ! pgrep -x "$APP_NAME" >/dev/null; then
            echo "Error: expected running process '$APP_NAME' was not found." >&2
            exit 1
        fi
        echo "Verified: $APP_NAME is running."
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
