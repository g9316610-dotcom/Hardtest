#!/usr/bin/env bash
set -euo pipefail

OUTDIR="results"
mkdir -p "$OUTDIR"

OUT="$OUTDIR/system.json"

CPU=$(lscpu -J)
DISKS=$(lsblk -J)
NVME=$(nvme list -o json 2>/dev/null || echo "{}")
SENSORS=$(sensors -j 2>/dev/null || echo "{}")

SMART=()

for d in /dev/nvme*n1 /dev/sd?; do
    [[ -b "$d" ]] || continue

    if [[ "$d" == /dev/nvme* ]]; then
        DATA=$(nvme smart-log "$d" --output-format=json 2>/dev/null || echo "{}")
    else
        DATA=$(smartctl -a -j "$d" 2>/dev/null || echo "{}")
    fi

    SMART+=("$DATA")
done

jq -n \
  --argjson cpu "$CPU" \
  --argjson disks "$DISKS" \
  --argjson nvme "$NVME" \
  --argjson sensors "$SENSORS" \
  --argjson smart "$(printf '%s\n' "${SMART[@]}" | jq -s '.')" \
  '{
    cpu:$cpu,
    disks:$disks,
    nvme:$nvme,
    sensors:$sensors,
    smart:$smart
  }' > "$OUT"

echo "Saved $OUT"
