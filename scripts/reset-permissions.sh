#!/bin/bash
# Reset DIYTypeless TCC permissions for a clean re-authorization cycle.

set -euo pipefail

BUNDLE_ID="com.lizunlong.DIYTypeless"
RESET_MICROPHONE=0
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: ./scripts/reset-permissions.sh [options]

Options:
  --bundle-id <id>         Bundle identifier to reset.
                           Default: com.lizunlong.DIYTypeless
  --include-microphone     Also reset Microphone permission.
  --dry-run                Print commands without executing them.
  -h, --help               Show this help message.

Notes:
  - Accessibility and Input Monitoring (ListenEvent) are always reset.
  - macOS may require you to quit/reopen System Settings to refresh UI.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bundle-id)
            if [[ $# -lt 2 ]]; then
                echo "Error: --bundle-id requires a value." >&2
                exit 1
            fi
            BUNDLE_ID="$2"
            shift 2
            ;;
        --include-microphone)
            RESET_MICROPHONE=1
            shift
            ;;
        --dry-run)
            DRY_RUN=1
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

if ! command -v tccutil >/dev/null 2>&1; then
    echo "Error: tccutil not found. This script must run on macOS." >&2
    exit 1
fi

SERVICES=(Accessibility ListenEvent)
if [[ "$RESET_MICROPHONE" -eq 1 ]]; then
    SERVICES+=(Microphone)
fi

echo "=== Resetting permissions for $BUNDLE_ID ==="
for service in "${SERVICES[@]}"; do
    cmd=(tccutil reset "$service" "$BUNDLE_ID")
    if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] ${cmd[*]}"
        continue
    fi

    echo "- Resetting $service"
    "${cmd[@]}"
done

if [[ "$DRY_RUN" -eq 0 ]]; then
    echo "Done. Launch the app and request permissions again."
fi

