#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../../results" && pwd)}"
mkdir -p "$RESULTS"
OUT="$RESULTS/cpu_test.json"
NCPU=$(nproc)
DURATION="${HARDTESTS_CPU_DURATION:-30}"

echo "  sysbench prime benchmark (${DURATION}s, ${NCPU} threads)..."
SB=$(sysbench cpu --cpu-max-prime=20000 --threads="$NCPU" --time="$DURATION" run)

EVENTS=$(awk '/total number of events/{print $NF}' <<< "$SB")
LAT_MIN=$(awk '/min:/{print $NF}' <<< "$SB")
LAT_AVG=$(awk '/avg:/{print $NF}' <<< "$SB")
LAT_MAX=$(awk '/max:/{print $NF}' <<< "$SB")
LAT_P95=$(awk '/95th percentile:/{print $NF}' <<< "$SB")
EPS=$(awk '/events per second:/{print $NF}' <<< "$SB")

echo "  stress-ng CPU stress (${DURATION}s, ${NCPU} workers) + freq monitoring..."

FREQ_LOG="$RESULTS/.cpu_freq_log"
> "$FREQ_LOG"

stress-ng --cpu "$NCPU" --timeout "${DURATION}s" --metrics-brief 2>&1 &
STRESS_PID=$!

get_avg_freq_mhz() {
    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        awk '{sum += $1; n++} END {if (n>0) printf "%.0f", sum/n/1000}' \
            /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null || echo "0"
    elif command -v lscpu >/dev/null 2>&1; then
        lscpu | awk '/^CPU MHz:/{printf "%.0f", $NF}'
    else
        echo "0"
    fi
}

ELAPSED=0
while kill -0 "$STRESS_PID" 2>/dev/null; do
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    FREQ=$(get_avg_freq_mhz)
    echo "${ELAPSED} ${FREQ}" >> "$FREQ_LOG"
    echo "    [${ELAPSED}s] avg CPU freq: ${FREQ} MHz"
done

wait "$STRESS_PID" || true

FREQ_JSON="[]"
if [[ -s "$FREQ_LOG" ]]; then
    FREQ_JSON=$(awk '{printf "%s{\"time_s\":%s,\"freq_mhz\":%s}", (NR>1?",":""), $1, $2}' "$FREQ_LOG")
    FREQ_JSON="[${FREQ_JSON}]"
fi

AVG_FREQ=$(awk '{sum += $2; n++} END {if (n>0) printf "%.0f", sum/n; else print "0"}' "$FREQ_LOG")

rm -f "$FREQ_LOG"

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
    --argjson avg_freq "$AVG_FREQ" \
    --argjson freq_samples "$FREQ_JSON" \
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
            avg_cpu_freq_mhz: $avg_freq,
            freq_samples: $freq_samples
        }
    }' > "$OUT"

echo "  Saved: $OUT"
