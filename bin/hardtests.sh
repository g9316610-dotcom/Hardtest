#!/usr/bin/env sh
set -eu

HARDTESTS_ROOT="${HARDTESTS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
export HARDTESTS_ROOT
export HARDTESTS_RESULTS="${HARDTESTS_RESULTS:-$HARDTESTS_ROOT/results}"

MODULES="$HARDTESTS_ROOT/modules"

usage() {
    cat <<EOF
Usage: hardtests <command> [args]

Commands:
  doctor              Check required tools are installed
  inventory           Collect system hardware information
  test [cpu|mem|disk] Run stress tests  (default: all)
  report              Display results report
  help                Show this help

Environment:
  HARDTESTS_RESULTS      Results directory  (default: ./results)
  HARDTESTS_CPU_DURATION CPU test duration  (default: 30s)
  HARDTESTS_MEM_MB       Memory to test     (default: 256 MB)
  HARDTESTS_DISK_SIZE    Disk test file     (default: 512M)
  HARDTESTS_DISK_DURATION Disk test runtime (default: 30s)
EOF
}

case "${1:-help}" in
    doctor)
        sh "$MODULES/doctor.sh"
        ;;
    inventory)
        bash "$MODULES/inventory.sh"
        ;;
    test)
        bash "$MODULES/test.sh" "${2:-all}"
        ;;
    report)
        bash "$MODULES/report.sh"
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo >&2
        usage >&2
        exit 1
        ;;
esac
