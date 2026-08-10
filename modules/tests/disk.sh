#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../../results" && pwd)}"
mkdir -p "$RESULTS"
OUT="$RESULTS/disk_test.json"

TESTFILE="$RESULTS/.fio_tmp"
SIZE="${HARDTESTS_DISK_SIZE:-512M}"
RUNTIME="${HARDTESTS_DISK_DURATION:-30}"

fio_run() {
    local name=$1 rw=$2 bs=$3 extra=${4:-}
    fio \
        --name="$name" \
        --rw="$rw"     \
        --bs="$bs"     \
        --size="$SIZE" \
        --runtime="$RUNTIME" \
        --time_based  \
        --direct=1    \
        --ioengine=libaio \
        --filename="$TESTFILE" \
        --output-format=json \
        $extra 2>/dev/null
}

echo "  fio sequential read  (bs=1M, ${RUNTIME}s)..."
SEQ_R=$(fio_run seq_read  read     1M)

echo "  fio sequential write (bs=1M, ${RUNTIME}s)..."
SEQ_W=$(fio_run seq_write write    1M)

echo "  fio random read  4K  (iodepth=32, ${RUNTIME}s)..."
RND_R=$(fio_run rand_read  randread  4K "--iodepth=32")

echo "  fio random write 4K  (iodepth=32, ${RUNTIME}s)..."
RND_W=$(fio_run rand_write randwrite 4K "--iodepth=32")

rm -f "$TESTFILE"

jq -n \
    --arg  ts       "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg  size     "$SIZE"    \
    --argjson rt    "$RUNTIME" \
    --argjson seq_r "$SEQ_R"  \
    --argjson seq_w "$SEQ_W"  \
    --argjson rnd_r "$RND_R"  \
    --argjson rnd_w "$RND_W"  \
    '{
        timestamp:   $ts,
        test_size:   $size,
        duration_s:  $rt,
        sequential: {
            read_mb_s:  ($seq_r.jobs[0].read.bw  / 1024 | round),
            write_mb_s: ($seq_w.jobs[0].write.bw / 1024 | round)
        },
        random_4k: {
            read_iops:   ($rnd_r.jobs[0].read.iops  | round),
            write_iops:  ($rnd_w.jobs[0].write.iops | round),
            read_lat_us: ($rnd_r.jobs[0].read.lat_ns.mean  / 1000 | round),
            write_lat_us:($rnd_w.jobs[0].write.lat_ns.mean / 1000 | round)
        }
    }' > "$OUT"

echo "  Saved: $OUT"
