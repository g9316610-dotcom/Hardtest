#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../../results" && pwd)}"
mkdir -p "$RESULTS"
OUT="$RESULTS/cpu_test.json"
NCPU=$(nproc)
DURATION="${HARDTESTS_CPU_DURATION:-30}"

# sysbench: синтетический бенчмарк, измеряет throughput и латентность
echo "  sysbench prime benchmark (${DURATION}s, ${NCPU} threads)..."
SB=$(sysbench cpu --cpu-max-prime=20000 --threads="$NCPU" --time="$DURATION" run)

EVENTS=$(awk '/total number of events/{print $NF}' <<< "$SB")
LAT_MIN=$(awk '/min:/{print $NF}' <<< "$SB")
LAT_AVG=$(awk '/avg:/{print $NF}' <<< "$SB")
LAT_MAX=$(awk '/max:/{print $NF}' <<< "$SB")
LAT_P95=$(awk '/95th percentile:/{print $NF}' <<< "$SB")
EPS=$(awk '/events per second:/{print $NF}' <<< "$SB")

# stress-ng: реальная стресс-нагрузка, разные паттерны (ALU, FPU, ветвления)
echo "  stress-ng CPU stress (${DURATION}s, ${NCPU} workers)..."
SNG=$(stress-ng --cpu "$NCPU" --timeout "${DURATION}s" --metrics-brief 2>&1 || true)

BOGO_OPS=$(awk '/metrc:.*cpu /{print $(NF-1)}' <<< "$SNG" | tail -1)
BOGO_OPS="${BOGO_OPS:-0}"

jq -n \
    --arg  ts       "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson threads  "$NCPU"     \
    --argjson duration "$DURATION" \
    --arg  events   "$EVENTS"   \
    --arg  eps      "$EPS"      \
    --arg  lat_min  "$LAT_MIN"  \
    --arg  lat_avg  "$LAT_AVG"  \
    --arg  lat_max  "$LAT_MAX"  \
    --arg  lat_p95  "$LAT_P95"  \
    --arg  bogo     "$BOGO_OPS" \
    '{
        timestamp:  $ts,
        threads:    $threads,
        duration_s: $duration,
        sysbench: {
            events_total:      ($events | tonumber),
            events_per_second: ($eps    | tonumber),
            latency_ms: {
                min: ($lat_min | tonumber),
                avg: ($lat_avg | tonumber),
                max: ($lat_max | tonumber),
                p95: ($lat_p95 | tonumber)
            }
        },
        stress_ng: {
            bogo_ops_per_sec: ($bogo | tonumber)
        }
    }' > "$OUT"

echo "  Saved: $OUT"
