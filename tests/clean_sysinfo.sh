#!/usr/bin/env bash
set -eou pipefail

OUTDIR="js_res"
mkdir -p "$OUTDIR"

OUT="$OUTDIR/sys.json"

CPU_JSON=$(lscpu --j)
DISK=$(lsblk -d -o NAME,ROTA,TRAN,TYPE,SIZE,MODEL --j)

CPU=$(jq -r '.lscpu[] | select(.field=="CPU(s):") | .data' <<< "$CPU_JSON")

PROC=$(jq -r '.lscpu[] | select(.field=="Model name:") | .data' <<< $CPU_JSON)



echo $CPU

