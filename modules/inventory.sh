#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../results" && pwd)}"
mkdir -p "$RESULTS"
OUT="$RESULTS/inventory.json"

echo "Collecting system inventory..."

CPU=$(lscpu -J)
DISKS=$(lsblk -J)
MEM_TOTAL=$(awk '/MemTotal/{print $2 * 1024}' /proc/meminfo)
MEM_FREE=$(awk '/MemAvailable/{print $2 * 1024}' /proc/meminfo)
MEM=$(printf '{"total":%s,"free":%s}' "$MEM_TOTAL" "$MEM_FREE")
NVME=$(nvme list -o json 2>/dev/null || echo '{"Devices":[]}')
jq -e . <<< "$NVME" >/dev/null 2>&1 || NVME='{"Devices":[]}'

SENSORS=$(sensors -j 2>/dev/null || echo '{}')
jq -e . <<< "$SENSORS" >/dev/null 2>&1 || SENSORS='{}'

SMART_LIST="[]"
for d in /dev/nvme*n1 /dev/sd?; do
    [[ -b "$d" ]] || continue
    if [[ "$d" == /dev/nvme* ]]; then
        RAW=$(nvme smart-log "$d" --output-format=json 2>/dev/null || true)
        DATA=$(jq 'if has("error") then {} else . end' <<< "${RAW:-{\}}" 2>/dev/null || echo '{}')
        DATA=$(jq --arg dev "$d" '. + {device:$dev}' <<< "$DATA")
    else
        DATA=$(smartctl -a -j "$d" 2>/dev/null || echo '{}')
    fi
    if jq -e . <<< "$DATA" >/dev/null 2>&1; then
        SMART_LIST=$(jq --argjson d "$DATA" '. + [$d]' <<< "$SMART_LIST")
    fi
done

jq -n \
    --argjson cpu     "$CPU"     \
    --argjson disks   "$DISKS"   \
    --argjson mem     "$MEM"     \
    --argjson nvme    "$NVME"    \
    --argjson sensors "$SENSORS" \
    --argjson smart   "$SMART_LIST" \
    '{cpu:$cpu, disks:$disks, mem:$mem, nvme:$nvme, sensors:$sensors, smart:$smart}' > "$OUT"

echo "Saved: $OUT"
