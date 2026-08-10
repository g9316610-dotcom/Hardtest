#!/usr/bin/env sh
set -eu

REQ="fio jq smartctl nvme stress-ng sysbench memtester sensors lsblk lscpu hdparm"

PASSED=""
FAILED=""

check() {
    if command -v "$1" >/dev/null 2>&1; then
        printf "  [OK]   %s\n" "$1"
        PASSED="$PASSED $1"
    else
        printf "  [MISS] %s\n" "$1"
        FAILED="$FAILED $1"
    fi
}

echo "Checking required tools..."
echo
for cmd in $REQ; do
    check "$cmd"
done
echo

if [ -n "$FAILED" ]; then
    echo "Missing:$FAILED"
    echo
    echo "Hint: run 'nix develop' to enter the dev shell with all tools."
    exit 1
else
    echo "All tools present."
fi
