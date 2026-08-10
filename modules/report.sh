#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../results" && pwd)}"

hr() { echo "━━━ $1 $(printf '%.0s━' {1..50})" | cut -c1-60; }

echo
hr "HardTests Report"
echo "  Generated : $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "  Results   : $RESULTS"

# ── Inventory ──────────────────────────────────────────────
if [[ -f "$RESULTS/inventory.json" ]]; then
    echo
    hr "System"
    jq -r '
        (.cpu.lscpu[] | select(.field=="Model name:")  | "  CPU    : " + .data),
        (.cpu.lscpu[] | select(.field=="CPU(s):")      | "  Cores  : " + .data),
        (.cpu.lscpu[] | select(.field=="CPU max MHz:") | "  MaxMHz : " + .data)
    ' "$RESULTS/inventory.json"

    jq -r '
        "  RAM    : " +
        (.mem.total / 1073741824 * 10 | round / 10 | tostring) + " GB total, " +
        (.mem.free  / 1073741824 * 10 | round / 10 | tostring) + " GB free"
    ' "$RESULTS/inventory.json"

    jq -r '
        .nvme.Devices[]? |
        "  NVMe   : " + .ModelNumber +
        " (" + (.PhysicalSize / 1073741824 | round | tostring) + " GB)"
    ' "$RESULTS/inventory.json"

    echo
    hr "Temperatures"
    jq -r '
        .sensors | to_entries[] |
        .key as $chip |
        .value | to_entries[] |
        select(.value | type == "object") |
        .key as $sensor |
        .value | to_entries[] |
        select(.key | test("^temp[0-9]+_input$")) |
        "  \($chip) / \($sensor): \(.value * 10 | round / 10)°C"
    ' "$RESULTS/inventory.json" 2>/dev/null || true

    echo
    hr "Disks"
    jq -r '
        .disks.blockdevices[] |
        select(.type == "disk") |
        "  \(.name)  \(.size)  \(."maj:min")"
    ' "$RESULTS/inventory.json"

    echo
    hr "SMART"
    jq -r '
        .smart[] |
        if .device then "  Device : " + .device else "" end,
        if .percent_used  != null then "  % used : " + (.percent_used | tostring) + "%" else "" end,
        if .avail_spare   != null then "  Spare  : " + (.avail_spare  | tostring) + "%" else "" end,
        if .media_errors  != null then "  Errors : " + (.media_errors | tostring) else "" end,
        if .power_on_hours!= null then "  Hours  : " + (.power_on_hours | tostring) + " h" else "" end,
        if .temperature   != null then "  Temp   : " + ((.temperature - 273) | tostring) + "°C" else "" end
    ' "$RESULTS/inventory.json" 2>/dev/null | grep -v '^$' || true
else
    echo
    echo "  [!] No inventory found. Run: hardtests inventory"
fi

# ── CPU Test ───────────────────────────────────────────────
if [[ -f "$RESULTS/cpu_test.json" ]]; then
    echo
    hr "CPU Test"
    jq -r '
        "  Threads      : " + (.threads                        | tostring),
        "  [sysbench]",
        "  Throughput   : " + (.sysbench.events_per_second     | tostring) + " events/s",
        "  Latency avg  : " + (.sysbench.latency_ms.avg        | tostring) + " ms",
        "  Latency p95  : " + (.sysbench.latency_ms.p95        | tostring) + " ms",
        "  [stress-ng]",
        "  Bogo ops/s   : " + (.stress_ng.bogo_ops_per_sec     | tostring),
        "  Tested at    : " + .timestamp
    ' "$RESULTS/cpu_test.json"
else
    echo; echo "  [!] No CPU test results. Run: hardtests test cpu"
fi

# ── Memory Test ────────────────────────────────────────────
if [[ -f "$RESULTS/mem_test.json" ]]; then
    echo
    hr "Memory Test"
    jq -r '
        "  Tested       : " + (.tested_mb    | tostring) + " MB",
        "  Passed       : " + (.tests_passed | tostring) + " tests",
        "  Failed       : " + (.tests_failed | tostring) + " tests",
        "  Status       : " + .status,
        "  Tested at    : " + .timestamp
    ' "$RESULTS/mem_test.json"
else
    echo; echo "  [!] No memory test results. Run: hardtests test mem"
fi

# ── Disk Test ──────────────────────────────────────────────
if [[ -f "$RESULTS/disk_test.json" ]]; then
    echo
    hr "Disk Test"
    jq -r '
        "  Seq read     : " + (.sequential.read_mb_s  | tostring) + " MB/s",
        "  Seq write    : " + (.sequential.write_mb_s | tostring) + " MB/s",
        "  Rand read    : " + (.random_4k.read_iops   | tostring) + " IOPS  (" + (.random_4k.read_lat_us  | tostring) + " µs)",
        "  Rand write   : " + (.random_4k.write_iops  | tostring) + " IOPS  (" + (.random_4k.write_lat_us | tostring) + " µs)",
        "  Tested at    : " + .timestamp
    ' "$RESULTS/disk_test.json"
else
    echo; echo "  [!] No disk test results. Run: hardtests test disk"
fi

echo
