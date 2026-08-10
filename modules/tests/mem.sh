#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../../results" && pwd)}"
mkdir -p "$RESULTS"
OUT="$RESULTS/mem_test.json"

MEM_MB="${HARDTESTS_MEM_MB:-256}"

echo "  memtester ${MEM_MB}MB (1 pass)..."
MT_OUT=$(memtester "${MEM_MB}M" 1 2>&1 || true)

PASSED=$(grep -c ': ok'      <<< "$MT_OUT" || echo 0)
FAILED=$(grep -c 'FAILURE'   <<< "$MT_OUT" || echo 0)
SKIPPED=$(grep -c 'Skipping' <<< "$MT_OUT" || echo 0)
STATUS=$([ "$FAILED" -gt 0 ] && echo "FAIL" || echo "PASS")

jq -n \
    --arg  ts      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --argjson mb   "$MEM_MB"  \
    --argjson pass "$PASSED"  \
    --argjson fail "$FAILED"  \
    --argjson skip "$SKIPPED" \
    --arg  status  "$STATUS"  \
    '{
        timestamp:    $ts,
        tested_mb:    $mb,
        tests_passed: $pass,
        tests_failed: $fail,
        tests_skipped:$skip,
        status:       $status
    }' > "$OUT"

echo "  Saved: $OUT"
