#!/usr/bin/env bash
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/tests" && pwd)"
export HARDTESTS_RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../results" && pwd)}"

SUITE="${1:-all}"

run() {
    local label=$1 script=$2
    echo "==> $label"
    bash "$TESTS_DIR/$script.sh"
    echo
}

case "$SUITE" in
    all)
        run "CPU"    cpu
        run "Disk"   disk
        ;;
    cpu)   run "CPU"    cpu  ;;
    disk)  run "Disk"   disk ;;
    *)
        echo "Unknown test suite: $SUITE" >&2
        echo "Available: cpu, disk, all" >&2
        exit 1
        ;;
esac

echo "Done. Run: hardtests report"
