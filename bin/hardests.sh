#!/usr/bin/env sh

set -eu

usage() {
    cat <<EOF
Usage:
  hardtests doctor
  hardtests inventory
  hardtests test
  hardtests report
EOF
}

case "${1:-help}" in
    doctor)
        echo "Doctor module"
        ;;
    inventory)
        echo "Inventory module"
        ;;
    test)
        echo "Test module"
        ;;
    report)
        echo "Report module"
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Unknown command: $1" >&2
        echo >&2
        usage
        exit 1
        ;;
esac
