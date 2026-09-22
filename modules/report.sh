#!/usr/bin/env bash
set -euo pipefail

RESULTS="${HARDTESTS_RESULTS:-$(cd "$(dirname "$0")/../results" && pwd)}"

hr() { echo "━━━ $1 $(printf '%.0s━' {1..50})" | cut -c1-60; }

echo
hr "HardTests Report"
echo "  Generated : $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "  Results   : $RESULTS"

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
        "  Device : " + .device + " (" + .type + ")",
        (if .health != null then "  Health : " + (if .health then "PASSED" else "FAILED" end) else "" end),
        (if .percent_used  != null then "  % used : " + (.percent_used | tostring) + "%" else "" end),
        (if .avail_spare   != null then "  Spare  : " + (.avail_spare  | tostring) + "%" else "" end),
        (if .media_errors  != null then "  Errors : " + (.media_errors | tostring) else "" end),
        (if .power_on_hours!= null then "  Hours  : " + (.power_on_hours | tostring) + " h" else "" end),
        (if .temperature   != null then "  Temp   : " + (.temperature | tostring) + "°C" else "" end),
        ""
    ' "$RESULTS/inventory.json" 2>/dev/null | grep -v '^$' || true
else
    echo
    echo "  [!] No inventory found. Run: hardtests inventory"
fi

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
        "  Avg CPU freq : " + (.stress_ng.avg_cpu_freq_mhz     | tostring) + " MHz",
        "  Freq samples :"
    ' "$RESULTS/cpu_test.json"
    jq -r '
        .stress_ng.freq_samples[]? |
        "    " + (.time_s | tostring) + "s : " + (.freq_mhz | tostring) + " MHz"
    ' "$RESULTS/cpu_test.json"
    jq -r '
        "  Tested at    : " + .timestamp
    ' "$RESULTS/cpu_test.json"
else
    echo; echo "  [!] No CPU test results. Run: hardtests test cpu"
fi

if [[ -f "$RESULTS/disk_test.json" ]]; then
    echo
    hr "Disk Test"
    jq -r '
        .disks[] |
        "  \(.device) (\(.type))",
        "    Seq read  : " + (.read_mb_s  | tostring) + " MB/s",
        "    Seq write : " + (.write_mb_s | tostring) + " MB/s"
    ' "$RESULTS/disk_test.json"
    jq -r '
        "  Tested at    : " + .timestamp
    ' "$RESULTS/disk_test.json"
else
    echo; echo "  [!] No disk test results. Run: hardtests test disk"
fi

echo
