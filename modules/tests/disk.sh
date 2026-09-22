#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../../results" && pwd)}"
mkdir -p "$RESULTS"
OUT="$RESULTS/disk_test.json"

SIZE="${HARDTESTS_DISK_SIZE:-512M}"
RUNTIME="${HARDTESTS_DISK_DURATION:-30}"

if command -v ionice >/dev/null 2>&1; then
    FIO_ENGINE=libaio
    fio --name=probe --ioengine=libaio --rw=read --bs=4k --size=4k --runtime=1 \
        --filename=/tmp/.fio_probe --output=/dev/null 2>/dev/null && rm -f /tmp/.fio_probe \
        || FIO_ENGINE=posixaio
else
    FIO_ENGINE=posixaio
fi

DISKS=()
for d in /dev/nvme*n1 /dev/sd? /dev/vd?; do
    [[ -b "$d" ]] || continue
    DISKS+=("$d")
done

if [[ ${#DISKS[@]} -eq 0 ]]; then
    echo "  No disks found to test" >&2
    exit 1
fi

fio_run() {
    local name=$1 rw=$2 bs=$3 file=$4
    fio \
        --name="$name" \
        --rw="$rw"     \
        --bs="$bs"     \
        --size="$SIZE" \
        --runtime="$RUNTIME" \
        --time_based  \
        --direct=1    \
        --ioengine="$FIO_ENGINE" \
        --filename="$file" \
        --output-format=json \
        2>/dev/null
}

RESULTS_JSON="[]"

for DISK in "${DISKS[@]}"; do
    DNAME=$(basename "$DISK")
    TESTFILE="/tmp/.fio_tmp_${DNAME}"

    MOUNTPOINT=$(lsblk -no MOUNTPOINT "$DISK" 2>/dev/null | head -1)
    if [[ -n "$MOUNTPOINT" ]]; then
        TESTFILE="${MOUNTPOINT}/.fio_tmp_hardtests"
    fi

    DTYPE=$(lsblk -dno ROTA "$DISK" 2>/dev/null | tr -d ' ')
    if [[ "$DISK" == /dev/nvme* ]]; then
        DLABEL="nvme"
    elif [[ "$DTYPE" == "0" ]]; then
        DLABEL="ssd"
    else
        DLABEL="hdd"
    fi

    echo "  [$DNAME ($DLABEL)] sequential read  (bs=1M, ${RUNTIME}s)..."
    SEQ_R=$(fio_run "seq_read_${DNAME}" read 1M "$TESTFILE")

    echo "  [$DNAME ($DLABEL)] sequential write (bs=1M, ${RUNTIME}s)..."
    SEQ_W=$(fio_run "seq_write_${DNAME}" write 1M "$TESTFILE")

    rm -f "$TESTFILE"

    ENTRY=$(jq -n \
        --arg  dev   "$DISK"   \
        --arg  type  "$DLABEL" \
        --argjson seq_r "$SEQ_R" \
        --argjson seq_w "$SEQ_W" \
        '{
            device: $dev,
            type:   $type,
            read_mb_s:  ($seq_r.jobs[0].read.bw  / 1024 | round),
            write_mb_s: ($seq_w.jobs[0].write.bw / 1024 | round)
        }')

    RESULTS_JSON=$(jq --argjson e "$ENTRY" '. + [$e]' <<< "$RESULTS_JSON")
done

jq -n \
    --arg  ts      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg  size    "$SIZE"    \
    --argjson rt   "$RUNTIME" \
    --argjson disks "$RESULTS_JSON" \
    '{
        timestamp:  $ts,
        test_size:  $size,
        duration_s: $rt,
        disks:      $disks
    }' > "$OUT"

echo "  Saved: $OUT"
